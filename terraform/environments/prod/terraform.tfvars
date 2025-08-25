# terraform/environments/prod/terraform.tfvars

# General Configuration
project_name = "wordpress-eks"
environment  = "prod"
owner       = "DevOps Team"
aws_region  = "us-west-2"

# VPC Configuration
vpc_cidr               = "10.0.0.0/16"
public_subnet_count    = 2
private_subnet_count   = 2
public_subnet_cidrs    = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs   = ["10.0.10.0/24", "10.0.20.0/24"]

# EKS Configuration
kubernetes_version = "1.28"
capacity_type     = "ON_DEMAND"
instance_types    = ["t3.medium"]
ami_type         = "AL2_x86_64"
disk_size        = 20

# Node Group Scaling
desired_size = 2
max_size     = 4
min_size     = 1

# SSH Access (optional - set to your key pair name if needed)
# key_pair_name = "your-key-pair-name"

# EFS Configuration
efs_performance_mode                = "generalPurpose"
efs_throughput_mode                = "bursting"
efs_provisioned_throughput_in_mibps = 100
efs_transition_to_ia               = "AFTER_30_DAYS"
efs_backup_policy_status           = "ENABLED"

# EFS CSI Driver Version
efs_csi_driver_version = "v1.7.0-eksbuild.1"