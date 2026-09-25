# Bucket and prefix come from backend/lz.hcl (the backend block can't use variables).

terraform {
  backend "gcs" {}
}
