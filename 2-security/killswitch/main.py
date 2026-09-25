"""Budget kill switch: detach billing from a project whose budget is exhausted (ADR 035).

Receives budget notifications (Pub/Sub push) for budgets named "project:<id>". Only projects in
the DEV folder can actually be detached: the service account has billing rights there and
nowhere else, so a bug here can't take down prod or the landing zone. Standard library only,
so there's no image to build or dependency to patch.
"""
import base64
import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

ENFORCE = os.environ.get("ENFORCE", "false") == "true"
TOKEN_URL = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token"


def log(severity, message, **fields):
    # Cloud Run parses JSON lines on stdout into structured log entries
    print(json.dumps({"severity": severity, "message": message, **fields}), flush=True)


def access_token():
    request = urllib.request.Request(TOKEN_URL, headers={"Metadata-Flavor": "Google"})
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.load(response)["access_token"]


def detach_billing(project_id):
    request = urllib.request.Request(
        f"https://cloudbilling.googleapis.com/v1/projects/{project_id}/billingInfo",
        data=json.dumps({"billingAccountName": ""}).encode(),
        method="PUT",
        headers={"Authorization": f"Bearer {access_token()}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def handle(notification):
    name = notification.get("budgetDisplayName", "")
    cost = float(notification.get("costAmount", 0))
    budget = float(notification.get("budgetAmount", 0))
    if not name.startswith("project:") or budget <= 0 or cost < budget:
        return
    project_id = name.split(":", 1)[1]
    fields = {"project": project_id, "cost": cost, "budget": budget}
    if not ENFORCE:
        log("WARNING", "budget exhausted: would detach billing (ENFORCE=false)", **fields)
        return
    try:
        detach_billing(project_id)
        log("CRITICAL", "budget exhausted: billing detached", **fields)
    except urllib.error.HTTPError as error:
        # 403 is expected for non-DEV projects: the SA has no billing rights there
        log("ERROR", "detach failed", status=error.code, body=error.read().decode()[:500], **fields)


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            envelope = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            handle(json.loads(base64.b64decode(envelope["message"]["data"])))
        except Exception as error:  # noqa: BLE001 — any bad message is logged and acked
            log("ERROR", "unprocessable message", error=str(error))
        # Always ack: budgets re-notify several times a day, which is the retry
        self.send_response(204)
        self.end_headers()

    def log_message(self, *args):
        pass


HTTPServer(("", int(os.environ.get("PORT", "8080"))), Handler).serve_forever()
