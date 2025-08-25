# terraform/modules/efs/main.tf

########################################
# KMS Key for EFS encryption
########################################
resource "aws_kms_key" "efs" {
  description             = "EFS encryption key for ${var.project_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-efs-kms-key" }
  )
}

resource "aws_kms_alias" "efs" {
  name          = "alias/${var.project_name}-efs-encryption-key"
  target_key_id = aws_kms_key.efs.key_id
}

########################################
# EFS File System
########################################
resource "aws_efs_file_system" "wordpress" {
  creation_token   = "${var.project_name}-wordpress-efs"
  performance_mode = var.performance_mode
  throughput_mode  = var.throughput_mode

  dynamic "provisioned_throughput_in_mibps" {
    for_each = var.throughput_mode == "provisioned" ? [var.provisioned_throughput_in_mibps] : []
    content {
      provisioned_throughput_in_mibps = provisioned_throughput_in_mibps.value
    }
  }

  encrypted  = true
  kms_key_id = aws_kms_key.efs.arn

  lifecycle_policy {
    transition_to_ia = var.transition_to_ia
  }

  # اختياري: رجّع الملفات من IA إلى Standard بعد أول وصول
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-wordpress-efs" }
  )
}

########################################
# Security Group for EFS
########################################
resource "aws_security_group" "efs" {
  name_prefix = "${var.project_name}-efs-sg-"
  description = "Security group for EFS mount targets"
  vpc_id      = var.vpc_id

  # خروج مفتوح (مطلوب غالباً مع SGs في VPC)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(
    var.tags,
    { Name = "${var.project_name}-efs-sg" }
  )
}

# اسمح بالـ NFS (2049/TCP) من Security Group تبع الـ Nodes (إذا متوفر)
resource "aws_security_group_rule" "efs_from_nodes_sg" {
  count                    = var.node_security_group_id != "" ? 1 : 0
  type                     = "ingress"
  security_group_id        = aws_security_group.efs.id
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = var.node_security_group_id
  description              = "Allow NFS from EKS nodes SG"
}

# أو بديلًا: اسمح من CIDR blocks محددة (إذا ما عندك SG للـ Nodes)
resource "aws_security_group_rule" "efs_from_cidrs" {
  for_each          = toset(var.allowed_cidr_blocks)
  type              = "ingress"
  security_group_id = aws_security_group.efs.id
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  description       = "Allow NFS from CIDR ${each.value}"
}

########################################
# EFS Mount Targets (واحد لكل Subnet)
########################################
resource "aws_efs_mount_target" "this" {
  for_each        = toset(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

