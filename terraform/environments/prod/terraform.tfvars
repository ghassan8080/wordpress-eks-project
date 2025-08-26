# terraform/environments/prod/terraform.tfvars.example
# Copy this file to terraform.tfvars and customize the values

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
capacity_type     = "ON_DEMAND"        # Options: ON_DEMAND, SPOT
instance_types    = ["t3.medium"]       # For demo: t3.small is cheaper
ami_type         = "AL2_x86_64"
disk_size        = 20

# Node Group Scaling - Simplified for demo/test
desired_size = 2
max_size     = 3
min_size     = 1

# SSH Access (optional - uncomment and set if you need SSH access to nodes)
# key_pair_name = "your-key-pair-name"

# EFS Configuration - Optimized for cost
efs_performance_mode                = "generalPurpose"  # Options: generalPurpose, maxIO
efs_throughput_mode                = "bursting"         # Options: bursting, provisioned
efs_provisioned_throughput_in_mibps = 100              # Only used if throughput_mode = "provisioned"
efs_transition_to_ia               = "AFTER_30_DAYS"    # Options: AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS
efs_enable_backup_policy           = false              # Disabled for demo to save costs

# EFS CSI Driver Version (check AWS documentation for latest)
efs_csi_driver_version = "v1.7.0-eksbuild.1"

# === DEMO/TEST OPTIMIZED SETTINGS ===
# For minimal cost testing, use:
# capacity_type = "SPOT"              # Use spot instances
# instance_types = ["t3.small"]       # Smaller instances
# desired_size = 1                    # Single node
# max_size = 2
# min_size = 1

# === PRODUCTION SETTINGS ===
# For production with higher load:
# instance_types = ["t3.large", "t3.xlarge"]
# desired_size = 3
# max_size = 10
# min_size = 2
# efs_enable_backup_policy = true