#!/bin/bash
# scripts/deploy-infra.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_NAME="wordpress-eks"
ENVIRONMENT="prod"
AWS_REGION="${AWS_REGION:-us-west-2}"
TF_BUCKET_NAME="${TF_STATE_BUCKET:-${PROJECT_NAME}-state-${ENVIRONMENT}}"
TF_DDB_TABLE="${TF_STATE_LOCK_TABLE:-${PROJECT_NAME}-locks-${ENVIRONMENT}}"
TF_KEY="wordpress-eks/terraform.tfstate"

echo -e "${YELLOW}📦 Bootstrapping Terraform backend (S3 + DynamoDB)...${NC}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo -e "${RED}❌ Required command not found: $1${NC}"; exit 1
  fi
}

require_cmd aws
require_cmd terraform

export AWS_REGION

# Create S3 bucket if missing
if ! aws s3api head-bucket --bucket "$TF_BUCKET_NAME" 2>/dev/null; then
  echo -e "${YELLOW}🪣 Creating S3 bucket: ${TF_BUCKET_NAME} in ${AWS_REGION}${NC}"
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$TF_BUCKET_NAME"
  else
    aws s3api create-bucket --bucket "$TF_BUCKET_NAME" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi
  aws s3api put-bucket-versioning --bucket "$TF_BUCKET_NAME" \
    --versioning-configuration Status=Enabled
fi

# Create DynamoDB table for state locking if missing
if ! aws dynamodb describe-table --table-name "$TF_DDB_TABLE" >/dev/null 2>&1; then
  echo -e "${YELLOW}🔒 Creating DynamoDB table: ${TF_DDB_TABLE}${NC}"
  aws dynamodb create-table \
    --table-name "$TF_DDB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION"
  echo -e "${YELLOW}⏳ Waiting for DynamoDB table to be ACTIVE...${NC}"
  aws dynamodb wait table-exists --table-name "$TF_DDB_TABLE"
fi

TF_DIR="terraform/environments/${ENVIRONMENT}"
echo -e "${YELLOW}🔧 Initializing Terraform in ${TF_DIR}...${NC}"
pushd "$TF_DIR" >/dev/null

terraform init -reconfigure \
  -backend-config="bucket=${TF_BUCKET_NAME}" \
  -backend-config="key=${TF_KEY}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_DDB_TABLE}"

echo -e "${YELLOW}🏗️  Planning infrastructure...${NC}"
terraform plan -out tfplan \
  -var="aws_region=${AWS_REGION}"

echo -e "${YELLOW}🚀 Applying infrastructure...${NC}"
terraform apply -auto-approve tfplan

popd >/dev/null

echo -e "${GREEN}✅ Infrastructure deployed successfully.${NC}"
echo -e "${YELLOW}ℹ️  Next: run scripts/setup-cluster.sh to install WordPress components${NC}"


