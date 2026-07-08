output "api_url" {
  description = "The HTTP POST invoke URL to trigger the serverless data pipeline"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/ingest"
}

output "sqs_queue_url" {
  description = "The URL of the main SQS message queue"
  value       = aws_sqs_queue.main.url
}

output "sqs_dlq_url" {
  description = "The URL of the SQS Dead Letter Queue"
  value       = aws_sqs_queue.dlq.url
}

output "s3_bucket_name" {
  description = "The name of the target S3 data bucket"
  value       = aws_s3_bucket.data.id
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB metadata storage table"
  value       = aws_dynamodb_table.metadata.name
}
