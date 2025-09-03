# 🚀 WordPress on EKS - Complete Infrastructure & Deployment

A production-ready WordPress deployment on Amazon EKS with MySQL database, Redis caching, EFS persistent storage, and automated CI/CD using GitHub Actions and Terraform.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────────────────────────────┐   │
│  │   VPC       │  │              EKS Cluster                │   │
│  │ (terraform/ │  │ (terraform/modules/eks + k8s-manifests/)│   │
│  │ modules/vpc)|  │                                         │   │
│  │ ┌─────────┐ │  │  ┌─────────────┐  ┌─────────────────────┐│   │
│  │ │  ALB    │ │  │  │ WordPress   │  │      MySQL         ││   │
│  │ └─────────┘ │  │  │(k8s/wordpress)│ │ (k8s/mysql)       ││   │
│  │             │  │  └─────────────┘  └─────────────────────┘│   │
│  │ ┌─────────┐ │  │  ┌─────────────┐                        │   │
│  │ │  EFS    │ │  │  │   Redis     │     ┌─────────────────┐│   │
│  │ └─────────┘ │  │  │(k8s/redis)  │     │  EFS Storage    ││   │
│  │             │  │  └─────────────┘     │  (k8s/efs)      ││   │
│  └─────────────┘  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## ✨ Features

- **🎯 Production Ready**: High availability, auto-scaling, health checks
- **🔒 Security**: Private subnets, encrypted storage, secrets management
- **💾 Persistent Storage**: EFS for WordPress files, EBS for MySQL data
- **⚡ Performance**: Redis caching, optimized container resources
- **🔄 CI/CD**: Automated deployment with GitHub Actions
- **📊 Monitoring**: CloudWatch integration, comprehensive logging
- **🌐 Load Balancing**: Application Load Balancer with SSL support

## 📋 Prerequisites

Before you begin, ensure you have:

### Required Tools
- [AWS CLI](https://aws.amazon.com/cli/) (configured with appropriate permissions)
- [Terraform](https://www.terraform.io/downloads.html) (>= 1.0)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Git](https://git-scm.com/downloads)

### AWS Requirements
- AWS Account with administrative access
- S3 bucket for Terraform state storage
- IAM permissions for EKS, VPC, EFS, and related services

### GitHub Setup
- GitHub repository
- GitHub Secrets configured (see [Configuration](#-configuration))

## 🚀 Quick Start

### 1. Clone and Configure

```bash
# Clone the repository
git clone <your-repo-url>
cd wordpress-eks-project

# Make scripts executable
chmod +x scripts/*.sh

# Configure your environment
cp terraform/environments/prod/terraform.tfvars.example terraform/environments/prod/terraform.tfvars
# Edit the file with your specific values
```

### 2. Set Up GitHub Secrets

In your GitHub repository, go to Settings → Secrets and variables → Actions, and add:

```
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-west-2
# Optional: override defaults used by scripts
TF_STATE_BUCKET=wordpress-eks-state-prod
TF_STATE_LOCK_TABLE=wordpress-eks-locks-prod
```

### 3. Deploy Infrastructure

**Option A: Using GitHub Actions (Recommended)**
1. Push your code to the `main` branch
2. Go to Actions tab in GitHub
3. Run "Deploy Infrastructure" workflow

**Option B: Local Deployment (WSL)**
```bash
# From repo root (WSL)
chmod +x scripts/*.sh
export AWS_PROFILE=default   # or configure AWS creds via aws configure
export AWS_REGION=us-west-2

# One command deploy
make infra

# Or run script directly
AWS_REGION=$AWS_REGION bash scripts/deploy-infra.sh
```

### 4. Deploy WordPress

**Option A: Automatic (after infrastructure deployment)**
The WordPress deployment workflow will run automatically after infrastructure is ready.

**Option B: Manual Deployment**
```bash
# Setup cluster resources and install WordPress
AWS_REGION=$AWS_REGION bash scripts/setup-cluster.sh

# Or deploy manually
AWS_REGION=$AWS_REGION bash scripts/deploy-wordpress.sh
```

### 5. Access Your Site

After deployment completes:
```bash
# Get the access URL
kubectl get ingress wordpress-ingress -n wordpress

# Or use the script
./scripts/setup-cluster.sh url
```

## 📁 Project Structure

```
wordpress-eks-project/
├── archive/                    # Old/unused scripts, configs, and docs
├── terraform/                  # Infrastructure as Code
│   ├── modules/                # VPC, EKS, EFS modules
│   └── environments/prod/      # Production environment configs
├── k8s-manifests/              # Kubernetes YAML files
│   ├── namespace.yaml
│   ├── mysql/                  # MySQL database manifests
│   ├── wordpress/              # WordPress manifests
│   ├── redis/                  # Redis cache manifests
│   └── efs/                    # EFS storage classes
├── scripts/                    # Utility scripts for deployment
│   ├── setup-cluster.sh
│   ├── deploy-infra.sh
│   ├── deploy-wordpress.sh
│   └── destroy-infra.sh
└── README.md
```

## ⚙️ Configuration

### Terraform Variables

Edit `terraform/environments/prod/terraform.tfvars`:

aws_region   = "us-west-2"
### 1. Clone and Configure

```bash
# Clone the repository
- ✅ Security groups with minimal required access
cd wordpress-eks-project

# Make scripts executable (Linux/WSL)
chmod +x scripts/*.sh

# Configure your environment
cp terraform/environments/prod/terraform.tfvars.example terraform/environments/prod/terraform.tfvars
# Edit the file with your specific values
```

### 2. Manual Deployment (Terraform & kubectl)

#### Deploy Infrastructure
```bash
# Initialize Terraform
cd terraform/environments/prod
terraform init

# Plan and apply infrastructure
terraform plan
terraform apply
```

#### Deploy Kubernetes Resources
```bash
# Configure kubectl for EKS
aws eks update-kubeconfig --region <your-region> --name <your-cluster-name>

# Apply Kubernetes manifests
kubectl apply -f ../../../../k8s-manifests/namespace.yaml
kubectl apply -f ../../../../k8s-manifests/mysql/
kubectl apply -f ../../../../k8s-manifests/wordpress/
kubectl apply -f ../../../../k8s-manifests/redis/
kubectl apply -f ../../../../k8s-manifests/efs/
```

#### Access Your Site
```bash
# Get the access URL
kubectl get ingress wordpress-ingress -n wordpress
```

#### Destroy Infrastructure
```bash
# Destroy Kubernetes resources
kubectl delete -f ../../../../k8s-manifests/wordpress/
kubectl delete -f ../../../../k8s-manifests/mysql/
kubectl delete -f ../../../../k8s-manifests/redis/
kubectl delete -f ../../../../k8s-manifests/efs/
kubectl delete namespace wordpress

# Destroy AWS infrastructure
terraform destroy
```
- ✅ VPC endpoints for AWS services

### Data Security
- ✅ Encrypted EBS volumes for MySQL
- ✅ Encrypted EFS file system
- ✅ Kubernetes secrets for sensitive data
- ✅ AWS Systems Manager Parameter Store

### Access Control
- ✅ IAM roles with least privilege
- ✅ Kubernetes RBAC
- ✅ Private EKS API endpoint option

## 🚨 Troubleshooting

### Common Issues

**1. WordPress pods stuck in pending**
```bash
# Check storage class
kubectl get storageclass

# Check PVC status
kubectl get pvc -n wordpress

# Check EFS mount targets
aws efs describe-mount-targets --file-system-id <efs-id>
```

**2. MySQL connection failed**
```bash
# Check MySQL pod logs
kubectl logs -f deployment/mysql -n wordpress

# Check secrets
kubectl get secrets -n wordpress
```

**3. Load balancer not accessible**
```bash
# Check ingress status
kubectl describe ingress wordpress-ingress -n wordpress

# Check ALB controller logs
kubectl logs -f deployment/aws-load-balancer-controller -n kube-system
```

### Debug Commands
```bash
# Get detailed cluster info
kubectl cluster-info dump

# Check node status
kubectl describe nodes

# Check all events
kubectl get events --sort-by=.metadata.creationTimestamp -n wordpress
```

## 🧹 Cleanup

### Complete Cleanup
```bash
# Clean up everything
./scripts/cleanup.sh
```

### Partial Cleanup
```bash
# Clean up only Kubernetes resources
./scripts/cleanup.sh k8s-only

# Clean up only infrastructure
./scripts/cleanup.sh terraform-only
```

## 💰 Cost Optimization

### Cost Estimates (us-west-2)
- **EKS Cluster**: ~$73/month
- **EC2 Instances** (2x t3.medium): ~$60/month
- **EFS Storage**: ~$0.30/GB/month
- **EBS Storage**: ~$0.10/GB/month
- **ALB**: ~$23/month
- **NAT Gateway**: ~$32/month

**Total**: ~$188-220/month (depending on storage usage)

### Cost Saving Tips
1. Use Spot instances for non-production environments
2. Enable EFS Intelligent Tiering
3. Use smaller instance types for development
4. Clean up unused resources regularly

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- AWS EKS Documentation
- Kubernetes Community
- WordPress Community
- Terraform AWS Provider

## 📞 Support

- Create an issue for bug reports
- Use discussions for questions
- Check AWS documentation for service-specific issues

---

**🎉 Happy WordPressing on Kubernetes!** 

Made with ❤️ for the DevOps community