# DynamoDB Global Table (Active-Active Multi-Region Replication)
resource "aws_dynamodb_table" "visits" {
  provider     = aws.primary
  name         = "${var.project_name}-visits"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  # DynamoDB Streams are required to sync writes/replicas between regions
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "session_id"
    type = "S"
  }

  # Secondary Region Replica (Replicated automatically by AWS DynamoDB)
  replica {
    region_name = var.secondary_region # us-west-2
  }

  tags = {
    Name = "${var.project_name}-global-table"
  }
}
