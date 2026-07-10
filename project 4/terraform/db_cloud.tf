# Security Group for AWS Cloud Target Database
resource "aws_security_group" "cloud_db" {
  name        = "${var.project_name}-cloud-db-sg"
  description = "Allows ingress database connections from within Cloud VPC subnets"
  vpc_id      = aws_vpc.cloud.id

  # Allow PGSQL inbound connections from the Cloud VPC range (where the DMS instance resides)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.cloud.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-cloud-db-sg"
  }
}

# RDS Target Database Instance (AWS Managed Environment)
resource "aws_db_instance" "cloud_db" {
  identifier             = "${var.project_name}-target-rds"
  db_name                = "target_db"
  allocated_storage      = 20
  max_allocated_storage  = 100
  engine                 = "postgres"
  engine_version         = "14" # Match source DB version major
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.cloud.name
  vpc_security_group_ids = [aws_security_group.cloud_db.id]
  skip_final_snapshot    = true

  tags = {
    Name = "${var.project_name}-target-rds"
  }
}
