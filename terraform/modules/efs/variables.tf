# terraform/modules/efs/variables.tf

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where EFS will be created"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs (one per AZ) for EFS mount targets"
}

# يفضَّل تمرير SG تبع الـ Node Group من موديول الـ EKS
variable "node_security_group_id" {
  type        = string
  description = "EKS worker node Security Group ID (preferred)"
  default     = ""
}

# كبديل إذا ما عندك SG للـ Nodes
variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to access EFS (NFS 2049)"
  default     = []
}

variable "performance_mode" {
  type        = string
  description = "EFS performance mode (generalPurpose or maxIO)"
  default     = "generalPurpose"
  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "performance_mode must be 'generalPurpose' or 'maxIO'."
  }
}

variable "throughput_mode" {
  type        = string
  description = "EFS throughput mode (bursting or provisioned)"
  default     = "bursting"
  validation {
    condition     = contains(["bursting", "provisioned"], var.throughput_mode)
    error_message = "throughput_mode must be 'bursting' or 'provisioned'."
  }
}

variable "provisioned_throughput_in_mibps" {
  type        = number
  description = "Required when throughput_mode is 'provisioned'"
  default     = 0
}

# قيم صالحة: AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS, AFTER_180_DAYS, AFTER_270_DAYS
variable "transition_to_ia" {
  type        = string
  description = "Transition to Infrequent Access"
  default     = "AFTER_30_DAYS"
}

variable "enable_backup_policy" {
  type        = bool
  description = "Enable AWS Backup policy for this EFS"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default     = {}
}
