# terraform/environments/prod/outputs.tf
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.wordpress.endpoint
}

output "wordpress_service_url" {
  description = "WordPress service URL"
  value       = "http://${kubernetes_service.wordpress.load_balancer_ingress[0].hostname}"
}

