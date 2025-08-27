# terraform/environments/prod/backend.hcl
# Example backend file. Replace placeholders with real values (or let CI write this file dynamically).
# If you run terraform locally, either:
# 1) replace TF_STATE_BUCKET and TF_STATE_LOCK_TABLE below with real names, or
# 2) keep a backend.hcl.local and pass it: terraform init -backend-config=backend.hcl.local

bucket         = "my-terraform-state-bucket"      # e.g. my-terraform-state-bucket
key            = "wordpress-eks/prod/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "terraform-state-lock"  # e.g. terraform-state-lock
encrypt        = true
