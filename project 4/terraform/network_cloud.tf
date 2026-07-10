# AWS Cloud VPC (Target Migration Environment)
resource "aws_vpc" "cloud" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-cloud-vpc"
  }
}

# Subnet A (Private)
resource "aws_subnet" "cloud_private_a" {
  vpc_id            = aws_vpc.cloud.id
  cidr_block        = "172.16.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-cloud-private-subnet-a"
  }
}

# Subnet B (Private - Multi-AZ Database requirement)
resource "aws_subnet" "cloud_private_b" {
  vpc_id            = aws_vpc.cloud.id
  cidr_block        = "172.16.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${var.project_name}-cloud-private-subnet-b"
  }
}

# DB Subnet Group for RDS
resource "aws_db_subnet_group" "cloud" {
  name       = "${var.project_name}-cloud-db-subnet-group"
  subnet_ids = [aws_subnet.cloud_private_a.id, aws_subnet.cloud_private_b.id]

  tags = {
    Name = "${var.project_name}-cloud-db-subnet-group"
  }
}

# Route Table for Cloud Subnets
resource "aws_route_table" "cloud_private" {
  vpc_id = aws_vpc.cloud.id

  tags = {
    Name = "${var.project_name}-cloud-private-rt"
  }
}

resource "aws_route_table_association" "cloud_private_a" {
  subnet_id      = aws_subnet.cloud_private_a.id
  route_table_id = aws_route_table.cloud_private.id
}

resource "aws_route_table_association" "cloud_private_b" {
  subnet_id      = aws_subnet.cloud_private_b.id
  route_table_id = aws_route_table.cloud_private.id
}
