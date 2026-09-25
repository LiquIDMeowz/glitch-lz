# Bucket and prefix come from backend/lz.hcl (the backend block can't use variables).
# First run was local; state migrated with: terraform init -migrate-state -backend-config=backend/lz.hcl
terraform {
  backend "gcs" {}
}
