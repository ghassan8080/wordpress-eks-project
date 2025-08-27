# backend.hcl — سيتم تمرير القيم الحقيقية عبر GitHub Actions Secrets أو متغيرات البيئة
bucket         = "TF_STATE_BUCKET"
key            = "wordpress-eks/prod/terraform.tfstate"
region         = "us-west-2"
dynamodb_table = "TF_LOCK_TABLE"
encrypt        = true
