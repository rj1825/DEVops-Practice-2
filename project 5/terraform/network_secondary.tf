# VPC Secondary (US-WEST-2)
resource "aws_vpc" "secondary" {
  provider             = aws.secondary
  cidr_block           = "10.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-secondary-vpc"
  }
}

resource "aws_internet_gateway" "secondary" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  tags = {
    Name = "${var.project_name}-secondary-igw"
  }
}

# Public Subnets (For Load Balancers)
resource "aws_subnet" "secondary_public_a" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "${var.secondary_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-secondary-public-subnet-a"
  }
}

resource "aws_subnet" "secondary_public_b" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary.id
  cidr_block              = "10.20.2.0/24"
  availability_zone       = "${var.secondary_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-secondary-public-subnet-b"
  }
}

# Private Subnets (For Application Instances)
resource "aws_subnet" "secondary_private_a" {
  provider          = aws.secondary
  vpc_id            = aws_vpc.secondary.id
  cidr_block        = "10.20.3.0/24"
  availability_zone = "${var.secondary_region}a"

  tags = {
    Name = "${var.project_name}-secondary-private-subnet-a"
  }
}

resource "aws_subnet" "secondary_private_b" {
  provider          = aws.secondary
  vpc_id            = aws_vpc.secondary.id
  cidr_block        = "10.20.4.0/24"
  availability_zone = "${var.secondary_region}b"

  tags = {
    Name = "${var.project_name}-secondary-private-subnet-b"
  }
}

# Route Tables
resource "aws_route_table" "secondary_public" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary.id
  }

  tags = {
    Name = "${var.project_name}-secondary-public-rt"
  }
}

resource "aws_route_table_association" "secondary_public_a" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_public_a.id
  route_table_id = aws_route_table.secondary_public.id
}

resource "aws_route_table_association" "secondary_public_b" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_public_b.id
  route_table_id = aws_route_table.secondary_public.id
}

resource "aws_route_table" "secondary_private" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary.id

  tags = {
    Name = "${var.project_name}-secondary-private-rt"
  }
}

resource "aws_route_table_association" "secondary_private_a" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_private_a.id
  route_table_id = aws_route_table.secondary_private.id
}

resource "aws_route_table_association" "secondary_private_b" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_private_b.id
  route_table_id = aws_route_table.secondary_private.id
}
