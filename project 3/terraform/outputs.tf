output "lambda_function_arn" {
  description = "The Amazon Resource Name (ARN) of the Lambda remediator function"
  value       = aws_lambda_function.remediator.arn
}

output "sns_topic_arn" {
  description = "The ARN of the SNS security alerts topic"
  value       = aws_sns_topic.alerts.arn
}

output "s3_eventbridge_rule_arn" {
  description = "The ARN of the S3 auditing EventBridge rule"
  value       = aws_cloudwatch_event_rule.s3_changes.arn
}

output "sg_eventbridge_rule_arn" {
  description = "The ARN of the Security Group auditing EventBridge rule"
  value       = aws_cloudwatch_event_rule.sg_changes.arn
}
