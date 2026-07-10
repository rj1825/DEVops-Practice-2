# VPC Primary (US-EAST-1)
resource "aws_vpc" "primary" {
  provider             = aws.primary
  cidr_block           = "10.10.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-primary-vpc"
  }
}

resource "aws_internet_gateway" "primary" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  tags = {
    Name = "${var.project_name}-primary-igw"
  }
}

# Public Subnets (For Load Balancers)
resource "aws_subnet" "primary_public_a" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "${var.primary_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-primary-public-subnet-a"
  }
}

resource "aws_subnet" "primary_public_b" {
  provider                = aws.primary
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "${var.primary_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-primary-public-subnet-b"
  }
}

# Private Subnets (For Application Instances)
resource "aws_subnet" "primary_private_a" {
  provider          = aws.primary
  vpc_id            = aws_vpc.primary.id
  cidr_block        = "10.10.3.0/24"
  availability_zone = "${var.primary_region}a"

  tags = {
    Name = "${var.project_name}-primary-private-subnet-a"
  }
}

resource "aws_subnet" "primary_private_b" {
  provider          = aws.primary
  vpc_id            = aws_vpc.primary.id
  cidr_block        = "10.10.4.0/24"
  availability_zone = "${var.primary_region}b"

  tags = {
    Name = "${var.project_name}-primary-private-subnet-b"
  }
}

# Route Tables
resource "aws_route_table" "primary_public" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary.id
  }

  tags = {
    Name = "${var.project_name}-primary-public-rt"
  }
}

resource "aws_route_table_association" "primary_public_a" {
  provider       = aws.primary
  subnet_id      = aws_subnet.primary_public_a.id
  route_table_id = aws_route_table.primary_public.id
}

resource "aws_route_table_association" "primary_public_b" {
  provider       = aws.primary
  subnet_id      = aws_subnet.primary_public_b.id
  route_table_id = aws_route_table.primary_public.id
}

resource "aws_route_table" "primary_private" {
  provider = aws.primary
  vpc_id   = aws_vpc.primary.id

  tags = {
    Name = "${var.project_name}-primary-private-rt"
  }
}

resource "aws_route_table_association" "primary_private_a" {
  provider       = aws.primary
  subnet_id      = aws_subnet.primary_private_a.id
  route_table_id = aws_route_table.primary_private.id
}

resource "aws_route_table_association" "primary_private_b" {
  provider       = aws.primary
  subnet_id      = aws_subnet.primary_private_b.id
  route_table_id = aws_route_table.primary_private.id
}
