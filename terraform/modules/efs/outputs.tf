# terraform/modules/efs/outputs.tf

output "file_system_id" {
  description = "The ID of the EFS file system"
  value       = aws_efs_file_system.wordpress.id
}

output "file_system_arn" {
  description = "Amazon Resource Name of the file system"
  value       = aws_efs_file_system.wordpress.arn
}

output "file_system_dns_name" {
  description = "The DNS name for the filesystem"
  value       = aws_efs_file_system.wordpress.dns_name
}

output "access_point_id" {
  description = "The ID of the EFS access point"
  value       = aws_efs_access_point.wordpress.id
}

output "access_point_arn" {
  description = "Amazon Resource Name of the access point"
  value       = aws_efs_access_point.wordpress.arn
}

output "mount_target_ids" {
  description = "The IDs of the EFS mount targets"
  value       = aws_efs_mount_target.wordpress[*].id
}

output "security_group_id" {
  description = "The ID of the security group for EFS"
  value       = aws_security_group.efs.id
}

output "kms_key_id" {
  description = "The ID of the KMS key used for encryption"
  value       = aws_kms_key.efs.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for encryption"
  value       = aws_kms_key.efs.arn
}

