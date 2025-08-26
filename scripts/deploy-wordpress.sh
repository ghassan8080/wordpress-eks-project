#!/bin/bash
# scripts/deploy-wordpress.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="wordpress-eks"
ENVIRONMENT="prod"
AWS_REGION="${AWS_REGION:-us-west-2}"

echo -e "${GREEN}🌐 Deploying WordPress to EKS cluster...${NC}"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for deployment
wait_for_deployment() {
    local deployment=$1
    local namespace=$2
    local timeout=${3:-300}
    
    echo -e "${YELLOW}⏳ Waiting for $deployment to be ready...${NC}"
    if kubectl wait --for=condition=available deployment/$deployment -n $namespace --timeout=${timeout}s; then
        echo -e "${GREEN}✅ $deployment is ready${NC}"
    else
        echo -e "${RED}❌ $deployment failed to become ready${NC}"
        kubectl describe deployment/$deployment -n $namespace
        exit 1
    fi
}

# Function to wait for pods
wait_for_pods() {
    local label=$1
    local namespace=$2
    local timeout=${3:-300}
    
    echo -e "${YELLOW}⏳ Waiting for pods with label $label...${NC}"
    if kubectl wait --for=condition=ready pod -l $label -n $namespace --timeout=${timeout}s; then
        echo -e "${GREEN}✅ Pods are ready${NC}"
    else
        echo -e "${RED}❌ Pods failed to become ready${NC}"
        kubectl get pods -l $label -n $namespace
        kubectl describe pods -l $label -n $namespace
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}📋 Checking prerequisites...${NC}"
    
    local required_commands=("kubectl" "aws")
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            echo -e "${RED}❌ $cmd is not installed${NC}"
            exit 1
        fi
    done
    
    # Test cluster connectivity
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
        echo -e "${YELLOW}💡 Make sure your kubeconfig is set up correctly${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Get cluster information
get_cluster_info() {
    echo -e "${BLUE}🔍 Getting cluster information...${NC}"
    
    # Get cluster info from SSM or kubectl
    CLUSTER_NAME=$(kubectl config current-context | cut -d'/' -f2 2>/dev/null || \
                   aws ssm get-parameter --name "/${PROJECT_NAME}/${ENVIRONMENT}/eks/cluster-name" --query 'Parameter.Value' --output text 2>/dev/null || \
                   echo "")
    
    if [ -z "$CLUSTER_NAME" ]; then
        echo -e "${RED}❌ Cannot determine cluster name${NC}"
        exit 1
    fi
    
    EFS_FILE_SYSTEM_ID=$(aws ssm get-parameter --name "/${PROJECT_NAME}/${ENVIRONMENT}/efs/file-system-id" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
    
    if [ -z "$EFS_FILE_SYSTEM_ID" ]; then
        echo -e "${RED}❌ Cannot find EFS file system ID${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Cluster: $CLUSTER_NAME${NC}"
    echo -e "${GREEN}✅ EFS: $EFS_FILE_SYSTEM_ID${NC}"
}

# Create namespace
create_namespace() {
    echo -e "${BLUE}📁 Creating WordPress namespace...${NC}"
    kubectl apply -f k8s-manifests/namespace.yaml
    echo -e "${GREEN}✅ Namespace created${NC}"
}

# Setup EFS storage
setup_efs_storage() {
    echo -e "${BLUE}💾 Setting up EFS storage...${NC}"
    
    # Create temporary file with EFS ID replacement
    sed "s/EFS_FILE_SYSTEM_ID_PLACEHOLDER/$EFS_FILE_SYSTEM_ID/g" k8s-manifests/efs/efs-storageclass.yaml > /tmp/efs-storageclass.yaml
    
    kubectl apply -f /tmp/efs-storageclass.yaml
    rm -f /tmp/efs-storageclass.yaml
    
    echo -e "${GREEN}✅ EFS storage class created${NC}"
}

# Create database secrets
create_db_secrets() {
    echo -e "${BLUE}🔐 Creating database secrets...${NC}"
    
    # Get credentials from SSM Parameter Store
    MYSQL_ROOT_PASSWORD=$(aws ssm get-parameter --name "/${PROJECT_NAME}/${ENVIRONMENT}/mysql/root-password" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null)
    MYSQL_PASSWORD=$(aws ssm get-parameter --name "/${PROJECT_NAME}/${ENVIRONMENT}/mysql/wordpress-password" --with-decryption --query 'Parameter.Value' --output text 2>/dev/null)
    
    if [ -z "$MYSQL_ROOT_PASSWORD" ] || [ -z "$MYSQL_PASSWORD" ]; then
        echo -e "${RED}❌ Cannot retrieve database passwords from SSM${NC}"
        exit 1
    fi
    
    # Create or update secret
    kubectl create secret generic mysql-secret \
        --from-literal=mysql-root-password="$MYSQL_ROOT_PASSWORD" \
        --from-literal=mysql-user="wordpress" \
        --from-literal=mysql-password="$MYSQL_PASSWORD" \
        --from-literal=mysql-database="wordpress" \
        --namespace=wordpress \
        --dry-run=client -o yaml | kubectl apply -f -
    
    echo -e "${GREEN}✅ Database secrets created${NC}"
}

# Deploy MySQL
deploy_mysql() {
    echo -e "${BLUE}🗄️ Deploying MySQL...${NC}"
    
    kubectl apply -f k8s-manifests/mysql/mysql-pvc.yaml
    kubectl apply -f k8s-manifests/mysql/mysql-deployment.yaml
    kubectl apply -f k8s-manifests/mysql/mysql-service.yaml
    
    wait_for_deployment "mysql" "wordpress" 300
    wait_for_pods "app=mysql" "wordpress" 300
    
    echo -e "${GREEN}✅ MySQL deployed successfully${NC}"
}

# Deploy Redis
deploy_redis() {
    echo -e "${BLUE}⚡ Deploying Redis...${NC}"
    
    kubectl apply -f k8s-manifests/redis/redis-deployment.yaml
    
    wait_for_deployment "redis" "wordpress" 120
    wait_for_pods "app=redis" "wordpress" 120
    
    echo -e "${GREEN}✅ Redis deployed successfully${NC}"
}

# Deploy WordPress
deploy_wordpress() {
    echo -e "${BLUE}🌐 Deploying WordPress...${NC}"
    
    kubectl apply -f k8s-manifests/wordpress/wordpress-pvc.yaml
    kubectl apply -f k8s-manifests/wordpress/wordpress-deployment.yaml
    kubectl apply -f k8s-manifests/wordpress/wordpress-service.yaml
    
    wait_for_deployment "wordpress" "wordpress" 300
    wait_for_pods "app=wordpress" "wordpress" 300
    
    echo -e "${GREEN}✅ WordPress deployed successfully${NC}"
}

# Setup ingress
setup_ingress() {
    echo -e "${BLUE}🌐 Setting up ingress...${NC}"
    
    # Check if AWS Load Balancer Controller is running
    if ! kubectl get deployment aws-load-balancer-controller -n kube-system >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  AWS Load Balancer Controller not found. Setting up...${NC}"
        setup_alb_controller
    fi
    
    # Create basic ingress (without SSL for now)
    cat > /tmp/wordpress-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wordpress-ingress
  namespace: wordpress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/tags: Environment=${ENVIRONMENT},Project=${PROJECT_NAME}
  labels:
    app: wordpress
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wordpress-service
            port:
              number: 80
EOF
    
    kubectl apply -f /tmp/wordpress-ingress.yaml
    rm -f /tmp/wordpress-ingress.yaml
    
    echo -e "${GREEN}✅ Ingress created${NC}"
}

# Setup AWS Load Balancer Controller (basic version)
setup_alb_controller() {
    echo -e "${BLUE}🔧 Setting up AWS Load Balancer Controller...${NC}"
    
    # This is a simplified version - for production, use the full setup from the GitHub Actions workflow
    kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.13.1/cert-manager.yaml
    
    # Wait for cert-manager
    sleep 30
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
    
    echo -e "${YELLOW}⚠️  For full ALB controller setup, please run the complete GitHub Actions workflow${NC}"
}

# Get access information
get_access_info() {
    echo -e "${BLUE}🔗 Getting access information...${NC}"
    
    # Wait for ingress to get an address
    echo -e "${YELLOW}⏳ Waiting for load balancer to be provisioned...${NC}"
    sleep 60
    
    LB_HOSTNAME=""
    for i in {1..20}; do
        LB_HOSTNAME=$(kubectl get ingress wordpress-ingress -n wordpress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ ! -z "$LB_HOSTNAME" ]; then
            break
        fi
        echo -e "${YELLOW}⏳ Still waiting for load balancer... (attempt $i/20)${NC}"
        sleep 30
    done
    
    if [ ! -z "$LB_HOSTNAME" ]; then
        echo -e "${GREEN}🎉 WordPress is accessible at: http://$LB_HOSTNAME${NC}"
        echo -e "${BLUE}📝 Complete the WordPress setup by visiting the URL above${NC}"
    else
        echo -e "${YELLOW}⚠️  Load balancer is still being provisioned. Check AWS console for ALB status.${NC}"
        echo -e "${BLUE}💡 You can check the status with: kubectl get ingress -n wordpress${NC}"
    fi
}

# Display status
show_status() {
    echo -e "\n${BLUE}📊 Deployment Status:${NC}"
    kubectl get all -n wordpress
    
    echo -e "\n${BLUE}💾 Storage Status:${NC}"
    kubectl get pv,pvc -n wordpress
    
    echo -e "\n${BLUE}🌐 Network Status:${NC}"
    kubectl get ingress -n wordpress
}

# Run health checks
run_health_checks() {
    echo -e "\n${BLUE}🏥 Running health checks...${NC}"
    
    # Check MySQL
    if kubectl exec -n wordpress deployment/mysql -- mysqladmin ping -uroot >/dev/null 2>&1; then
        echo -e "${GREEN}✅ MySQL is healthy${NC}"
    else
        echo -e "${YELLOW}⚠️  MySQL health check failed${NC}"
    fi
    
    # Check Redis
    if kubectl exec -n wordpress deployment/redis -- redis-cli ping >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Redis is healthy${NC}"
    else
        echo -e "${YELLOW}⚠️  Redis health check failed${NC}"
    fi
    
    # Check WordPress
    WORDPRESS_PODS=$(kubectl get pods -n wordpress -l app=wordpress --no-headers | wc -l)
    READY_PODS=$(kubectl get pods -n wordpress -l app=wordpress --no-headers | grep Running | wc -l)
    echo -e "${GREEN}✅ WordPress pods: $READY_PODS/$WORDPRESS_PODS ready${NC}"
}

# Main deployment function
main() {
    echo -e "${GREEN}🚀 Starting WordPress deployment...${NC}\n"
    
    check_prerequisites
    get_cluster_info
    create_namespace
    setup_efs_storage
    create_db_secrets
    deploy_mysql
    deploy_redis
    deploy_wordpress
    setup_ingress
    get_access_info
    show_status
    run_health_checks
    
    echo -e "\n${GREEN}🎉 WordPress deployment completed successfully!${NC}"
    echo -e "${BLUE}📚 Next steps:${NC}"
    echo -e "  1. Visit your WordPress site and complete the installation"
    echo -e "  2. Configure your site settings and themes"
    echo -e "  3. Set up backups for your content"
    echo -e "  4. Consider adding SSL certificate for production use"
}

# Handle script arguments
case "${1:-}" in
    "mysql")
        check_prerequisites
        get_cluster_info
        create_namespace
        create_db_secrets
        deploy_mysql
        ;;
    "wordpress")
        check_prerequisites
        get_cluster_info
        deploy_wordpress
        ;;
    "ingress")
        check_prerequisites
        setup_ingress
        get_access_info
        ;;
    "status")
        show_status
        run_health_checks
        ;;
    *)
        main
        ;;
esac