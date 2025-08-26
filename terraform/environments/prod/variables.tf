# terraform/environments/prod/variables.tf

# General Variables
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "wordpress-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "DevOps Team"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# VPC Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
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

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# EKS Variables
variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
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
  description = "Type of Amazon Machine Image (AMI)"
  type        = string
  default     = "AL2_x86_64"
}

variable "disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 20
}

variable "desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
  default     = null
}

variable "efs_csi_driver_version" {
  description = "EFS CSI Driver addon version"
  type        = string
  default     = "v1.7.0-eksbuild.1"
}

# EFS Variables
variable "efs_performance_mode" {
  description = "The file system performance mode"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "Throughput mode for the file system"
  type        = string
  default     = "bursting"
}

variable "efs_provisioned_throughput_in_mibps" {
  description = "The throughput, measured in MiB/s, that you want to provision for the file system"
  type        = number
  default     = 100
}

variable "efs_transition_to_ia" {
  description = "Indicates how long it takes to transition files to the IA storage class"
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "efs_enable_backup_policy" {
  description = "Enable backup policy for EFS"
  type        = bool
  default     = false
}