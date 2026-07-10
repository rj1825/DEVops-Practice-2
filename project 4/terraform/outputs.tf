output "onprem_db_public_ip" {
  description = "Public IP of the simulated On-Premises database host (for SSH verification)"
  value       = aws_instance.onprem_db_host.public_ip
}

output "onprem_db_private_ip" {
  description = "Private IP of the simulated On-Premises database host"
  value       = aws_instance.onprem_db_host.private_ip
}

output "target_rds_endpoint" {
  description = "Endpoint address of the target RDS PostgreSQL instance"
  value       = aws_db_instance.cloud_db.endpoint
}

output "dms_replication_task_arn" {
  description = "The ARN of the AWS DMS Database Migration Task"
  value       = aws_dms_replication_task.migration_task.replication_task_arn
}

output "vpc_peering_id" {
  description = "The ID of the established VPC Peering connection"
  value       = aws_vpc_peering_connection.peer.id
}
