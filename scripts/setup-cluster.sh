#!/bin/bash
# scripts/setup-cluster.sh

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

echo -e "${GREEN}🚀 Setting up WordPress on EKS cluster...${NC}"

# Check if required tools are installed
check_requirements() {
    echo -e "${YELLOW}📋 Checking requirements...${NC}"
    
    commands=("aws" "kubectl" "terraform")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}❌ $cmd is not installed${NC}"
            exit 1
        else
            echo -e "${GREEN}✅ $cmd is available${NC}"
        fi
    done
}

# Get cluster information
get_cluster_info() {
    echo -e "${YELLOW}🔍 Getting cluster information...${NC}"
    
    CLUSTER_NAME=$(aws ssm get-parameter --name "/${PROJECT_NAME}/${ENVIRONMENT}/eks/cluster-name" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    if [ -z "$CLUSTER_NAME" ]; then
        echo -e "${RED}❌ Cluster not found. Please deploy infrastructure first.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Found cluster: $CLUSTER_NAME${NC}"
    
    # Update kubeconfig
    echo -e "${YELLOW}🔧 Updating kubeconfig...${NC}"
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
    
    # Test connectivity
    echo -e "${YELLOW}🧪 Testing cluster connectivity...${NC}"
    kubectl get nodes
}

# Deploy WordPress stack
deploy_wordpress() {
    echo -e "${YELLOW}🎯 Deploying WordPress stack...${NC}"
    
    # Get EFS file system ID
    EFS_FILE_SYSTEM_ID=$(aws ssm get-parameter --name "/${PROJECT_NAME}/${ENVIRONMENT}/efs/file-system-id" --query 'Parameter.Value' --output text)
    
    # Get database credentials
    MYSQL_ROOT_PASSWORD=$(aws ssm get-parameter --name "/${PROJECT_NAME}/${ENVIRONMENT}/mysql/root-password" --with-decryption --query 'Parameter.Value' --output text)
    MYSQL_PASSWORD=$(aws ssm get-parameter --name "/${PROJECT_NAME}/${ENVIRONMENT}/mysql/wordpress-password" --with-decryption --query 'Parameter.Value' --output text)
    
    # Create namespace
    echo -e "${YELLOW}📁 Creating namespace...${NC}"
    kubectl apply -f k8s-manifests/namespace.yaml
    
    # Setup EFS Storage Class
    echo -e "${YELLOW}💾 Setting up EFS storage...${NC}"
    sed "s/EFS_FILE_SYSTEM_ID_PLACEHOLDER/$EFS_FILE_SYSTEM_ID/g" k8s-manifests/efs/efs-storageclass.yaml | kubectl apply -f -
    
    # Create secrets
    echo -e "${YELLOW}🔐 Creating secrets...${NC}"
    kubectl create secret generic mysql-secret \
        --from-literal=mysql-root-password="$MYSQL_ROOT_PASSWORD" \
        --from-literal=mysql-user="wordpress" \
        --from-literal=mysql-password="$MYSQL_PASSWORD" \
        --from-literal=mysql-database="wordpress" \
        --namespace=wordpress \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy MySQL
    echo -e "${YELLOW}🗄️ Deploying MySQL...${NC}"
    kubectl apply -f k8s-manifests/mysql/
    kubectl wait --for=condition=ready pod -l app=mysql -n wordpress --timeout=300s
    
    # Deploy Redis
    echo -e "${YELLOW}⚡ Deploying Redis...${NC}"
    kubectl apply -f k8s-manifests/redis/redis-deployment.yaml
    kubectl wait --for=condition=ready pod -l app=redis -n wordpress --timeout=120s
    
    # Deploy WordPress
    echo -e "${YELLOW}🌐 Deploying WordPress...${NC}"
    kubectl apply -f k8s-manifests/wordpress/
    kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress --timeout=300s
    
    echo -e "${GREEN}✅ WordPress stack deployed successfully!${NC}"
}

# Get access URL
get_access_url() {
    echo -e "${YELLOW}🔗 Getting access URL...${NC}"
    
    # Wait for ingress to be ready
    kubectl wait --for=condition=ready ingress/wordpress-ingress -n wordpress --timeout=300s || true
    
    LB_URL=$(kubectl get ingress wordpress-ingress -n wordpress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ ! -z "$LB_URL" ]; then
        echo -e "${GREEN}🎉 WordPress is accessible at: http://$LB_URL${NC}"
    else
        echo -e "${YELLOW}⏳ Load balancer is still being provisioned. Please check AWS console.${NC}"
    fi
}

# Display cluster status
show_status() {
    echo -e "${YELLOW}📊 Cluster Status:${NC}"
    kubectl get all -n wordpress
    
    echo -e "\n${YELLOW}💾 Storage Status:${NC}"
    kubectl get pv,pvc -n wordpress
    
    echo -e "\n${YELLOW}🌐 Network Status:${NC}"
    kubectl get ingress -n wordpress
}

# Main execution
main() {
    check_requirements
    get_cluster_info
    deploy_wordpress
    get_access_url
    show_status
    
    echo -e "\n${GREEN}🎉 Setup completed successfully!${NC}"
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo -e "  1. Access your WordPress site using the URL above"
    echo -e "  2. Complete the WordPress installation wizard"
    echo -e "  3. Configure your site settings"
    echo -e "\n${YELLOW}🔧 Useful commands:${NC}"
    echo -e "  - kubectl get all -n wordpress"
    echo -e "  - kubectl logs -f deployment/wordpress -n wordpress"
    echo -e "  - kubectl logs -f deployment/mysql -n wordpress"
}

# Handle script arguments
case "${1:-}" in
    "status")
        get_cluster_info
        show_status
        ;;
    "url")
        get_access_url
        ;;
    *)
        main
        ;;
esac