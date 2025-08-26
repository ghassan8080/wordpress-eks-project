# terraform/environments/prod/outputs.tf

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# EKS Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_version" {
  description = "The Kubernetes version for the EKS cluster"
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

# EFS Outputs
output "efs_file_system_id" {
  description = "The ID of the EFS file system"
  value       = module.efs.file_system_id
}

output "efs_file_system_arn" {
  description = "Amazon Resource Name of the file system"
  value       = module.efs.file_system_arn
}

output "efs_access_point_id" {
  description = "The ID of the EFS access point"
  value       = module.efs.access_point_id
}

output "efs_dns_name" {
  description = "The DNS name for the filesystem"
  value       = module.efs.file_system_dns_name
}

# Database Passwords (for reference only - actual values stored in SSM)
output "mysql_root_password_ssm_parameter" {
  description = "SSM Parameter Store path for MySQL root password"
  value       = aws_ssm_parameter.mysql_root_password.name
}

output "mysql_wordpress_password_ssm_parameter" {
  description = "SSM Parameter Store path for MySQL WordPress password"
  value       = aws_ssm_parameter.mysql_wordpress_password.name
}

# Configuration for kubectl
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${local.cluster_name}"
}

# Cluster name for reference
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = local.cluster_name
}