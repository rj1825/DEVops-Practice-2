# IAM Roles required by AWS DMS service
# Note: AWS requires these exact names. If they already exist in the AWS account, they do not need to be recreated.
resource "aws_iam_role" "dms_vpc_role" {
  name = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dms.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_vpc_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = aws_iam_role.dms_vpc_role.name
}

# DMS Subnet Group (Specifies which subnets the DMS instance runs in)
resource "aws_dms_replication_subnet_group" "dms" {
  replication_subnet_group_description = "Subnet group for DMS replication instance"
  replication_subnet_group_id          = "${var.project_name}-dms-subnet-group"
  subnet_ids                           = [aws_subnet.cloud_private_a.id, aws_subnet.cloud_private_b.id]
}

# DMS Replication Instance
resource "aws_dms_replication_instance" "dms" {
  allocated_storage            = 20
  apply_immediately            = true
  multi_az                     = false # Single AZ for cost-saving simulation
  publicly_accessible          = false # Keeps traffic inside private networks
  replication_instance_class   = "dms.t3.medium"
  replication_instance_id      = "${var.project_name}-repl-instance"
  replication_subnet_group_id  = aws_dms_replication_subnet_group.dms.id
  vpc_security_group_ids       = [aws_security_group.cloud_db.id] # Shares security group

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_role
  ]
}

# Source Endpoint (Legacy database running on EC2)
resource "aws_dms_endpoint" "source" {
  database_name = "legacy_db"
  endpoint_id   = "${var.project_name}-source-endpoint"
  endpoint_type = "source"
  engine_name   = "postgres"
  username      = var.db_username
  password      = var.db_password
  port          = 5432
  server_name   = aws_instance.onprem_db_host.private_ip # Resolves to the private peering IP
  ssl_mode      = "none"
}

# Target Endpoint (Managed RDS instance in the cloud)
resource "aws_dms_endpoint" "target" {
  database_name = aws_db_instance.cloud_db.db_name
  endpoint_id   = "${var.project_name}-target-endpoint"
  endpoint_type = "target"
  engine_name   = "postgres"
  username      = var.db_username
  password      = var.db_password
  port          = aws_db_instance.cloud_db.port
  server_name   = element(split(":", aws_db_instance.cloud_db.endpoint), 0) # Strips port from endpoint url
  ssl_mode      = "none"
}

# Database Migration Task
resource "aws_dms_replication_task" "migration_task" {
  migration_type            = "full-load-and-cdc" # Migrate existing data, then sync changes continuously
  replication_instance_arn  = aws_dms_replication_instance.dms.replication_instance_arn
  replication_task_id       = "${var.project_name}-task"
  source_endpoint_arn       = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn       = aws_dms_endpoint.target.endpoint_arn
  start_replication_task    = false # Do not auto-start until verified

  # Table mapping configuration to migrate all tables in the 'public' schema
  table_mappings = jsonencode({
    rules = [
      {
        rule-type = "selection"
        rule-id   = "1"
        rule-name = "1"
        object-locator = {
          schema-name = "public"
          table-name  = "%"
        }
        rule-action = "include"
      }
    ]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      TargetSchema = ""
      SupportLobs  = true
      LobMode      = "Full"
    }
    Logging = {
      EnableLogging = true
    }
  })
}
