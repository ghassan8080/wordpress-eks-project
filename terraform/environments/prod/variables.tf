# terraform/environments/prod/variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "wordpress-cluster"
}

variable "db_password" {
  description = "RDS database password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "wordpress_replicas" {
  description = "Number of WordPress replicas"
  type        = number
  default     = 2
}
