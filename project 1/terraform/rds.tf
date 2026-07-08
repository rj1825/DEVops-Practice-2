# Subnet Group grouping isolated database subnets for RDS placement
resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-db-subnet-group"
  description = "Subnet group for RDS PostgreSQL instance"
  subnet_ids  = aws_subnet.database[*].id

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Highly Available Multi-AZ PostgreSQL Database Instance
resource "aws_db_instance" "postgres" {
  identifier           = "${var.project_name}-postgres"
  engine               = "postgres"
  engine_version       = "15.7"
  instance_class       = "db.t4g.micro" # Graviton processor (free-tier / cost efficient)
  allocated_storage     = 20
  max_allocated_storage = 100 # Auto-scaling storage enabled

  db_name  = var.db_name
  username = var.db_user
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Enables Multi-AZ active-passive replication to a standby instance in another availability zone
  multi_az = true

  # Storage encryption at rest
  storage_encrypted = true

  # Security configurations
  publicly_accessible = false
  skip_final_snapshot = true # Disables final snapshot to allow fast teardown in testing

  tags = {
    Name = "${var.project_name}-postgres-db"
  }
}
