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

# Set AWS region
export AWS_REGION

# Check AWS credentials
echo -e "${YELLOW}🔐 Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo -e "${RED}❌ AWS credentials not configured or invalid${NC}"
  echo -e "${YELLOW}💡 Please run: aws configure${NC}"
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo -e "${GREEN}✅ AWS Account: ${ACCOUNT_ID}${NC}"
echo -e "${GREEN}✅ AWS Region: ${AWS_REGION}${NC}"

# Create S3 bucket if missing
echo -e "${YELLOW}🪣 Checking S3 bucket: ${TF_BUCKET_NAME}${NC}"

# Check if bucket exists and is accessible
BUCKET_EXISTS=false
if aws s3api head-bucket --bucket "$TF_BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
  BUCKET_EXISTS=true
  echo -e "${GREEN}✅ S3 bucket already exists and is accessible${NC}"
else
  echo -e "${YELLOW}🆕 Creating S3 bucket: ${TF_BUCKET_NAME} in ${AWS_REGION}${NC}"
  
  # Attempt to create bucket
  CREATE_RESULT=0
  if [ "$AWS_REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$TF_BUCKET_NAME" \
      --region "$AWS_REGION" 2>/dev/null || CREATE_RESULT=$?
  else
    aws s3api create-bucket \
      --bucket "$TF_BUCKET_NAME" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION" 2>/dev/null || CREATE_RESULT=$?
  fi
  
  # Handle bucket creation result
  if [ $CREATE_RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ S3 bucket created successfully${NC}"
    BUCKET_EXISTS=true
  elif aws s3api head-bucket --bucket "$TF_BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo -e "${GREEN}✅ S3 bucket already exists (this is fine)${NC}"
    BUCKET_EXISTS=true
  else
    echo -e "${RED}❌ Failed to create or access S3 bucket${NC}"
    exit 1
  fi
fi

# Configure bucket settings if we have access
if [ "$BUCKET_EXISTS" = true ]; then
  echo -e "${YELLOW}🔧 Configuring bucket settings...${NC}"
  
  # Enable versioning
  echo -e "${YELLOW}🔄 Ensuring versioning is enabled...${NC}"
  aws s3api put-bucket-versioning \
    --bucket "$TF_BUCKET_NAME" \
    --versioning-configuration Status=Enabled \
    --region "$AWS_REGION" 2>/dev/null || echo -e "${YELLOW}⚠️  Could not enable versioning (may already be enabled)${NC}"
  
  # Enable server-side encryption
  echo -e "${YELLOW}🔒 Ensuring encryption is enabled...${NC}"
  aws s3api put-bucket-encryption \
    --bucket "$TF_BUCKET_NAME" \
    --server-side-encryption-configuration '{
      "Rules": [
        {
          "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
          },
          "BucketKeyEnabled": true
        }
      ]
    }' \
    --region "$AWS_REGION" 2>/dev/null || echo -e "${YELLOW}⚠️  Could not configure encryption (may already be enabled)${NC}"
  
  # Block public access
  echo -e "${YELLOW}🚫 Ensuring public access is blocked...${NC}"
  aws s3api put-public-access-block \
    --bucket "$TF_BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
    --region "$AWS_REGION" 2>/dev/null || echo -e "${YELLOW}⚠️  Could not configure public access block (may already be configured)${NC}"
  
  echo -e "${GREEN}✅ S3 bucket configuration completed${NC}"
fi

# Create DynamoDB table for state locking if missing
echo -e "${YELLOW}🔒 Checking DynamoDB table: ${TF_DDB_TABLE}${NC}"

TABLE_EXISTS=false
if aws dynamodb describe-table --table-name "$TF_DDB_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
  TABLE_EXISTS=true
  echo -e "${GREEN}✅ DynamoDB table already exists${NC}"
else
  echo -e "${YELLOW}🆕 Creating DynamoDB table: ${TF_DDB_TABLE}${NC}"
  
  CREATE_RESULT=0
  aws dynamodb create-table \
    --table-name "$TF_DDB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$AWS_REGION" >/dev/null 2>&1 || CREATE_RESULT=$?
  
  if [ $CREATE_RESULT -eq 0 ]; then
    echo -e "${YELLOW}⏳ Waiting for DynamoDB table to be ACTIVE...${NC}"
    aws dynamodb wait table-exists --table-name "$TF_DDB_TABLE" --region "$AWS_REGION"
    echo -e "${GREEN}✅ DynamoDB table created successfully${NC}"
    TABLE_EXISTS=true
  elif aws dynamodb describe-table --table-name "$TF_DDB_TABLE" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ DynamoDB table already exists (this is fine)${NC}"
    TABLE_EXISTS=true
  else
    echo -e "${RED}❌ Failed to create or access DynamoDB table${NC}"
    exit 1
  fi
fi

# Verify table is active
if [ "$TABLE_EXISTS" = true ]; then
  TABLE_STATUS=$(aws dynamodb describe-table --table-name "$TF_DDB_TABLE" --region "$AWS_REGION" --query 'Table.TableStatus' --output text 2>/dev/null || echo "UNKNOWN")
  if [ "$TABLE_STATUS" = "ACTIVE" ]; then
    echo -e "${GREEN}✅ DynamoDB table is ACTIVE${NC}"
  else
    echo -e "${YELLOW}⏳ Waiting for DynamoDB table to become ACTIVE (current status: ${TABLE_STATUS})...${NC}"
    aws dynamodb wait table-exists --table-name "$TF_DDB_TABLE" --region "$AWS_REGION"
    echo -e "${GREEN}✅ DynamoDB table is now ACTIVE${NC}"
  fi
fi

TF_DIR="terraform/environments/${ENVIRONMENT}"
echo -e "${YELLOW}🔧 Initializing Terraform in ${TF_DIR}...${NC}"

# Navigate to terraform directory
if [ ! -d "$TF_DIR" ]; then
  echo -e "${RED}❌ Terraform directory not found: $TF_DIR${NC}"
  exit 1
fi

pushd "$TF_DIR" >/dev/null

# Initialize Terraform with backend configuration
echo -e "${YELLOW}⚙️  Configuring Terraform backend...${NC}"
terraform init -reconfigure \
  -backend-config="bucket=${TF_BUCKET_NAME}" \
  -backend-config="key=${TF_KEY}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_DDB_TABLE}"

# Validate Terraform configuration
echo -e "${YELLOW}✅ Validating Terraform configuration...${NC}"
terraform validate

# Plan infrastructure
echo -e "${YELLOW}🏗️  Planning infrastructure...${NC}"
terraform plan -out tfplan \
  -var="aws_region=${AWS_REGION}" \
  -detailed-exitcode

PLAN_EXIT_CODE=$?
case $PLAN_EXIT_CODE in
  0)
    echo -e "${GREEN}✅ No changes needed${NC}"
    ;;
  1)
    echo -e "${RED}❌ Terraform plan failed${NC}"
    popd >/dev/null
    exit 1
    ;;
  2)
    echo -e "${YELLOW}📋 Changes detected, proceeding with apply...${NC}"
    ;;
esac

# Apply infrastructure if there are changes
if [ $PLAN_EXIT_CODE -eq 2 ]; then
  echo -e "${YELLOW}🚀 Applying infrastructure changes...${NC}"
  terraform apply -auto-approve tfplan
  
  # Clean up plan file
  rm -f tfplan
  
  echo -e "${GREEN}✅ Infrastructure applied successfully${NC}"
else
  echo -e "${GREEN}✅ Infrastructure is up to date${NC}"
fi

popd >/dev/null

# Display outputs
echo -e "\n${GREEN}🎉 Infrastructure deployment completed!${NC}"
echo -e "\n${YELLOW}📊 Infrastructure Summary:${NC}"
echo -e "  🪣 S3 State Bucket: ${TF_BUCKET_NAME}"
echo -e "  🔒 DynamoDB Lock Table: ${TF_DDB_TABLE}"
echo -e "  🌍 AWS Region: ${AWS_REGION}"

# Get and display terraform outputs
echo -e "\n${YELLOW}📋 Terraform Outputs:${NC}"
pushd "$TF_DIR" >/dev/null
terraform output -json > /tmp/tf_outputs.json 2>/dev/null || true

if [ -f /tmp/tf_outputs.json ] && [ -s /tmp/tf_outputs.json ]; then
  if command -v jq >/dev/null 2>&1; then
    echo -e "${GREEN}  Cluster Name: $(jq -r '.cluster_name.value // "N/A"' /tmp/tf_outputs.json)${NC}"
    echo -e "${GREEN}  VPC ID: $(jq -r '.vpc_id.value // "N/A"' /tmp/tf_outputs.json)${NC}"
    echo -e "${GREEN}  EFS ID: $(jq -r '.efs_file_system_id.value // "N/A"' /tmp/tf_outputs.json)${NC}"
  else
    echo -e "${YELLOW}  (Install 'jq' to see formatted outputs)${NC}"
  fi
  rm -f /tmp/tf_outputs.json
fi

popd >/dev/null

echo -e "\n${YELLOW}🚀 Next Steps:${NC}"
echo -e "  1. Configure kubectl: aws eks update-kubeconfig --region ${AWS_REGION} --name wordpress-eks-prod"
echo -e "  2. Deploy WordPress: ./scripts/setup-cluster.sh"
echo -e "  3. Check cluster status: kubectl get nodes"

echo -e "\n${GREEN}✅ Ready to deploy WordPress!${NC}"