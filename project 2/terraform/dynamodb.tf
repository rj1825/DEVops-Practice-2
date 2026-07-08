# DynamoDB Table for metadata storage
resource "aws_dynamodb_table" "metadata" {
  name         = "${var.project_name}-metadata"
  billing_mode = "PAY_PER_REQUEST" # On-Demand billing (Serverless cost-efficiency)
  hash_key     = "message_id"

  attribute {
    name = "message_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-metadata-table"
  }
}
