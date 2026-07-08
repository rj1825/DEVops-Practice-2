output "vpc_id" {
  description = "The ID of the custom VPC"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "The public DNS endpoint of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "The connection endpoint for the PostgreSQL Database"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_database_name" {
  description = "The name of the database created"
  value       = aws_db_instance.postgres.db_name
}
