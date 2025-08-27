#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="$PROJECT_ROOT/terraform/environments/prod"

AWS_REGION="${AWS_REGION:-us-west-2}"
TF_STATE_BUCKET="${TF_STATE_BUCKET:?TF_STATE_BUCKET is required}"
TF_STATE_LOCK_TABLE="${TF_STATE_LOCK_TABLE:?TF_STATE_LOCK_TABLE is required}"

pushd "$ENV_DIR" >/dev/null

cat > backend.hcl <<EOF
bucket         = "${TF_STATE_BUCKET}"
key            = "wordpress-eks/prod/terraform.tfstate"
region         = "${AWS_REGION}"
dynamodb_table = "${TF_STATE_LOCK_TABLE}"
encrypt        = true
EOF

terraform init -upgrade -backend-config=backend.hcl
terraform destroy -auto-approve -lock=true -lock-timeout=5m -var="aws_region=${AWS_REGION}"

popd >/dev/null
echo "✅ Terraform destroy completed."
