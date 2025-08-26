# terraform/environments/prod/main.tf

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Backend configuration is handled via terraform init -backend-config
  # or in separate backend.tf file
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Local values
locals {
  cluster_name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name         = var.project_name
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_count  = var.public_subnet_count
  private_subnet_count = var.private_subnet_count
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  # Node group configuration
  capacity_type  = var.capacity_type
  instance_types = var.instance_types
  ami_type       = var.ami_type
  disk_size      = var.disk_size
  desired_size   = var.desired_size
  max_size       = var.max_size
  min_size       = var.min_size
  key_pair_name  = var.key_pair_name

  # EFS CSI driver
  efs_csi_driver_version = var.efs_csi_driver_version

  tags = local.common_tags

  depends_on = [module.vpc]
}

# EFS Module
module "efs" {
  source = "../../modules/efs"

  project_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  node_security_group_id = module.eks.cluster_security_group_id

  # EFS configuration
  performance_mode                = var.efs_performance_mode
  throughput_mode                 = var.efs_throughput_mode
  provisioned_throughput_in_mibps = var.efs_provisioned_throughput_in_mibps
  transition_to_ia                = var.efs_transition_to_ia
  enable_backup_policy            = var.efs_enable_backup_policy

  tags = local.common_tags

  depends_on = [module.eks]
}

# Random password for MySQL root user
resource "random_password" "mysql_root_password" {
  length  = 16
  special = true
}

# Random password for MySQL WordPress user
resource "random_password" "mysql_wordpress_password" {
  length  = 16
  special = true
}

# AWS Systems Manager Parameter Store for sensitive data
resource "aws_ssm_parameter" "mysql_root_password" {
  name  = "/${var.project_name}/${var.environment}/mysql/root-password"
  type  = "SecureString"
  value = random_password.mysql_root_password.result

  tags = local.common_tags
}

resource "aws_ssm_parameter" "mysql_wordpress_password" {
  name  = "/${var.project_name}/${var.environment}/mysql/wordpress-password"
  type  = "SecureString"
  value = random_password.mysql_wordpress_password.result

  tags = local.common_tags
}

# Store cluster configuration in SSM for later use
resource "aws_ssm_parameter" "cluster_name" {
  name  = "/${var.project_name}/${var.environment}/eks/cluster-name"
  type  = "String"
  value = local.cluster_name

  tags = local.common_tags
}

resource "aws_ssm_parameter" "cluster_endpoint" {
  name  = "/${var.project_name}/${var.environment}/eks/cluster-endpoint"
  type  = "String"
  value = module.eks.cluster_endpoint

  tags = local.common_tags
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${var.project_name}/${var.environment}/vpc/vpc-id"
  type  = "String"
  value = module.vpc.vpc_id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "efs_file_system_id" {
  name  = "/${var.project_name}/${var.environment}/efs/file-system-id"
  type  = "String"
  value = module.efs.file_system_id

  tags = local.common_tags
}

resource "aws_ssm_parameter" "efs_access_point_id" {
  name  = "/${var.project_name}/${var.environment}/efs/access-point-id"
  type  = "String"
  value = module.efs.access_point_id

  tags = local.common_tags
}