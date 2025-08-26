#!/bin/bash
# scripts/cleanup.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="wordpress-eks"
ENVIRONMENT="prod"
AWS_REGION="${AWS_REGION:-us-west-2}"

echo -e "${YELLOW}🧹 Cleaning up WordPress on EKS deployment...${NC}"

# Warning message
echo -e "${RED}⚠️  WARNING: This will destroy all resources and data!${NC}"
echo -e "${YELLOW}This includes:${NC}"
echo -e "  - WordPress application and data"
echo -e "  - MySQL database and all data"
echo -e "  - EKS cluster"
echo -e "  - VPC and networking"
echo -e "  - EFS file system"
echo -e "  - Load balancers"

read -p "Are you sure you want to proceed? (type 'yes' to confirm): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo -e "${GREEN}✅ Operation cancelled.${NC}"
    exit 0
fi

# Check if kubectl is configured
check_kubectl() {
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${YELLOW}⚠️  kubectl is not configured or cluster is not accessible${NC}"
        echo -e "${YELLOW}Proceeding with Terraform cleanup only...${NC}"
        return 1
    fi
    return 0
}

# Clean up Kubernetes resources
cleanup_kubernetes() {
    echo -e "${YELLOW}🗑️  Cleaning up Kubernetes resources...${NC}"
    
    if check_kubectl; then
        # Delete WordPress namespace (this will delete everything in it)
        echo -e "${YELLOW}📁 Deleting WordPress namespace...${NC}"
        kubectl delete namespace wordpress --ignore-not-found=true --timeout=300s
        
        # Delete AWS Load Balancer Controller
        echo -e "${YELLOW}🔧 Cleaning up AWS Load Balancer Controller...${NC}"
        kubectl delete -f k8s-manifests/aws-load-balancer-controller.yaml --ignore-not-found=true --timeout=300s
        
        # Delete cert-manager
        echo -e "${YELLOW}🔐 Cleaning up cert-manager...${NC}"
        kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.13.1/cert-manager.yaml --ignore-not-found=true --timeout=300s
        
        # Wait for finalizers to complete
        echo -e "${YELLOW}⏳ Waiting for resources to be fully deleted...${NC}"
        sleep 30
        
        echo -e "${GREEN}✅ Kubernetes resources cleaned up${NC}"
    else
        echo -e "${YELLOW}⚠️  Skipping Kubernetes cleanup${NC}"
    fi
}

# Clean up AWS IAM resources
cleanup_iam() {
    echo -e "${YELLOW}🔑 Cleaning up IAM resources...${NC}"
    
    # Detach and delete Load Balancer Controller policy
    aws iam detach-role-policy \
        --role-name AmazonEKSLoadBalancerControllerRole \
        --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy" \
        2>/dev/null || true
    
    aws iam delete-role --role-name AmazonEKSLoadBalancerControllerRole 2>/dev/null || true
    aws iam delete-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy" 2>/dev/null || true
    
    echo -e "${GREEN}✅ IAM resources cleaned up${NC}"
}

# Clean up with Terraform
cleanup_terraform() {
    echo -e "${YELLOW}🏗️  Cleaning up infrastructure with Terraform...${NC}"
    
    cd terraform/environments/prod
    
    # Initialize Terraform
    echo -e "${YELLOW}🔧 Initializing Terraform...${NC}"
    terraform init \
        -backend-config="bucket=${TF_STATE_BUCKET}" \
        -backend-config="key=wordpress-eks/terraform.tfstate" \
        -backend-config="region=${AWS_REGION}"
    
    # Destroy infrastructure
    echo -e "${YELLOW}💥 Destroying infrastructure...${NC}"
    terraform destroy -auto-approve \
        -var="aws_region=${AWS_REGION}"
    
    cd ../../..
    
    echo -e "${GREEN}✅ Infrastructure destroyed${NC}"
}

# Clean up local files
cleanup_local() {
    echo -e "${YELLOW}🧹 Cleaning up local files...${NC}"
    
    # Remove kubeconfig context
    CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}"
    kubectl config delete-context "arn:aws:eks:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${CLUSTER_NAME}" 2>/dev/null || true
    
    # Clean up temporary files
    rm -f terraform/environments/prod/.terraform.lock.hcl
    rm -rf terraform/environments/prod/.terraform/
    rm -f terraform/environments/prod/terraform.tfstate*
    rm -f iam_policy.json trust-policy.json
    rm -rf outputs/ deployment-info/
    
    echo -e "${GREEN}✅ Local files cleaned up${NC}"
}

# Main cleanup function
main() {
    echo -e "${YELLOW}🚀 Starting cleanup process...${NC}"
    
    # Set required environment variables if not set
    export TF_STATE_BUCKET="${TF_STATE_BUCKET:-ghassan8080-wordpress-eks-project}"
    
    if [ "$TF_STATE_BUCKET" = "ghassan8080-wordpress-eks-project" ]; then
        echo -e "${RED}❌ Please set TF_STATE_BUCKET environment variable${NC}"
        exit 1
    fi
    
    # Perform cleanup steps
    cleanup_kubernetes
    cleanup_iam
    cleanup_terraform
    cleanup_local
    
    echo -e "\n${GREEN}🎉 Cleanup completed successfully!${NC}"
    echo -e "${YELLOW}📝 Summary:${NC}"
    echo -e "  ✅ Kubernetes resources deleted"
    echo -e "  ✅ IAM resources cleaned up"
    echo -e "  ✅ Infrastructure destroyed"
    echo -e "  ✅ Local files cleaned up"
    echo -e "\n${GREEN}All resources have been successfully removed.${NC}"
}

# Handle script arguments
case "${1:-}" in
    "k8s-only")
        cleanup_kubernetes
        ;;
    "terraform-only")
        cleanup_terraform
        ;;
    "local-only")
        cleanup_local
        ;;
    *)
        main
        ;;
esac