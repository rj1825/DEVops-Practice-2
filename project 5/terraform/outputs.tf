output "primary_alb_dns" {
  description = "The public HTTP DNS URL of the primary region Application Load Balancer"
  value       = "http://${aws_lb.primary.dns_name}"
}

output "secondary_alb_dns" {
  description = "The public HTTP DNS URL of the secondary region Application Load Balancer"
  value       = "http://${aws_lb.secondary.dns_name}"
}

output "dynamodb_table_arn" {
  description = "The Amazon Resource Name (ARN) of the global DynamoDB visits table"
  value       = aws_dynamodb_table.visits.arn
}

output "route53_app_url" {
  description = "The global routing domain URL (Active-Active Latency / Failover link)"
  value       = var.domain_name != "" ? "http://app.${var.domain_name}" : "N/A (No domain name provided)"
}
