# terraform/environments/prod/terraform.tfvars
# project_name = "wordpress-eks"
# environment  = "prod"
# owner        = "DevOps Team"
# aws_region   = "us-west-2"

# # VPC (small)
# vpc_cidr             = "10.0.0.0/16"
# public_subnet_count  = 1
# private_subnet_count = 1
# public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
# private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]


# # EKS (minimal)
# kubernetes_version = "1.28"
# capacity_type      = "ON_DEMAND"
# instance_types     = ["t3.small"]   # small instance for test
# ami_type           = "AL2_x86_64"
# disk_size          = 20

# # Node Group - small scaling for test
# desired_size = 1
# min_size     = 1
# max_size     = 1

# # EFS - keep defaults but low-cost config
# efs_performance_mode                = "generalPurpose"
# efs_throughput_mode                 = "bursting"
# efs_provisioned_throughput_in_mibps = 0
# efs_transition_to_ia                = "AFTER_30_DAYS"
# efs_enable_backup_policy            = false


aws_region    = "us-west-2"
cluster_name  = "wordpress-cluster"
db_password   = "ChangeMe123!"
aws_region           = "us-west-2"
cluster_name         = "wordpress-cluster"
db_password          = "ChangeMe123!"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
wordpress_replicas   = 2
