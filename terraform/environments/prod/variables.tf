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
  default     = "wordpress123"  # Only for testing
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "wordpress-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_count" {
  description = "Number of public subnets"
  type        = number
  default     = 2
}

variable "private_subnet_count" {
  description = "Number of private subnets"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Whether to use a single NAT gateway"
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.27"  # Changed to 1.27 which is stable and supports AL2_x86_64
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  type        = string
  default     = "ON_DEMAND"
}

variable "instance_types" {
  description = "List of instance types associated with the EKS Node Group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group"
  type        = string
  default     = "AL2_x86_64"
}

variable "disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 20
}

variable "min_size" {
  description = "Minimum size of the Node Group"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum size of the Node Group"
  type        = number
  default     = 3
}

variable "desired_size" {
  description = "Desired size of the Node Group"
  type        = number
  default     = 2
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair to use for SSH access to worker nodes"
  type        = string
  default     = null
}

variable "efs_csi_driver_version" {
  description = "Version of the EFS CSI driver to install"
  type        = string
  default     = "v1.5.8-eksbuild.1"  # Check for the latest version
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

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

