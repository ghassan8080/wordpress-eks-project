# terraform/modules/efs/main.tf

# EFS File System
resource "aws_efs_file_system" "wordpress" {
  creation_token = "${var.project_name}-wordpress-efs"
  
  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode
  
  dynamic "provisioned_throughput_in_mibps" {
    for_each = var.throughput_mode == "provisioned" ? [var.provisioned_throughput_in_mibps] : []
    content {
      provisioned_throughput_in_mibps = provisioned_throughput_in_mibps.value
    }
  }

  encrypted = true
  kms_key_id = aws_kms_key.efs.arn

  lifecycle_policy {
    transition_to_ia = var.transition_to_ia
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-wordpress-efs"
    }
  )
}

# KMS Key for EFS encryption
resource "aws_kms_key" "efs" {
  description             = "EFS encryption key for ${var.project_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-efs-kms-key"
    }
  )
}

resource "aws_kms_alias" "efs" {
  name          = "alias/${var.project_name}-efs-encryption-key"
  target_key_id = aws_kms_key.efs.key_id
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  name_prefix = "${var.project_name}-efs-sg"
  vpc_id      = var.vpc_id
  description = "Security group for EFS mount targets"

  ingress {
    description     = "NFS from EKS nodes"
    from_port       = 2049
    to_port         =