# EventBridge Rule: Detect S3 API modifications via CloudTrail
resource "aws_cloudwatch_event_rule" "s3_changes" {
  name        = "${var.project_name}-s3-audit-rule"
  description = "Trigger Lambda remediator on critical S3 bucket policy or configuration changes"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName = [
        "CreateBucket",
        "PutBucketPublicAccessBlock",
        "DeletePublicAccessBlock",
        "PutBucketPolicy",
        "DeleteBucketPolicy"
      ]
    }
  })
}

# Target: Link S3 Rule to Lambda function
resource "aws_cloudwatch_event_target" "s3_target" {
  rule      = aws_cloudwatch_event_rule.s3_changes.name
  target_id = "S3RemediatorTarget"
  arn       = aws_lambda_function.remediator.arn
}

# Permission: Allow EventBridge to invoke Lambda for S3 rule
resource "aws_lambda_permission" "allow_eventbridge_s3" {
  statement_id  = "AllowExecutionFromEventBridgeS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_changes.arn
}

# EventBridge Rule: Detect EC2 Security Group modifications via CloudTrail
resource "aws_cloudwatch_event_rule" "sg_changes" {
  name        = "${var.project_name}-sg-audit-rule"
  description = "Trigger Lambda remediator on EC2 Security Group ingress authorization rule additions"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ec2.amazonaws.com"]
      eventName = [
        "AuthorizeSecurityGroupIngress",
        "CreateSecurityGroup"
      ]
    }
  })
}

# Target: Link SG Rule to Lambda function
resource "aws_cloudwatch_event_target" "sg_target" {
  rule      = aws_cloudwatch_event_rule.sg_changes.name
  target_id = "SGRemediatorTarget"
  arn       = aws_lambda_function.remediator.arn
}

# Permission: Allow EventBridge to invoke Lambda for SG rule
resource "aws_lambda_permission" "allow_eventbridge_sg" {
  statement_id  = "AllowExecutionFromEventBridgeSG"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sg_changes.arn
}
