# SQS Dead Letter Queue (DLQ) for failed message isolation
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = 1209600 # 14 days retention for troubleshooting

  tags = {
    Name = "${var.project_name}-dlq"
  }
}

# Main SQS Queue with Redrive Policy pointing to DLQ
resource "aws_sqs_queue" "main" {
  name                      = "${var.project_name}-queue"
  message_retention_seconds = 345600 # 4 days retention
  visibility_timeout_seconds = 30     # Must be >= Lambda execution timeout

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3 # Route to DLQ after 3 failures
  })

  tags = {
    Name = "${var.project_name}-queue"
  }
}
