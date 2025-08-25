# terraform/modules/efs/variables.tf

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EFS will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EFS mount targets"
  type        = list(string)
}

variable "node_security_group_id" {
  description = "Security group ID of the EKS node group"
  type        = string
}

variable "performance_mode" {
  description = "The file system performance mode. Can be either generalPurpose or maxIO"
  type        = string
  default     = "generalPurpose"
}

variable "throughput_mode" {
  description = "Throughput mode for the file system. Valid values: bursting, provisioned"
  type        = string
  default     = "bursting"
}

variable "provisioned_throughput_in_mibps" {
  description = "The throughput, measured in MiB/s, that you want to provision for the file system"
  type        = number
  default     = 100
}

variable "transition_to_ia" {
  description = "Indicates how long it takes to transition files to the IA storage class"
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "wordpress_uid" {
  description = "User ID for WordPress files"
  type        = number
  default     = 33
}

variable "wordpress_gid" {
  description = "Group ID for WordPress files"
  type        = number
  default     = 33
}

variable "backup_policy_status" {
  description = "A status of the backup policy (ENABLED or DISABLED)"
  type        = string
  default     = "ENABLED"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}