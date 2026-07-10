# On-Premises VPC (Simulates the legacy local datacenter)
resource "aws_vpc" "onprem" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-onprem-vpc"
  }
}

# Internet Gateway (for administrative access during test simulation)
resource "aws_internet_gateway" "onprem" {
  vpc_id = aws_vpc.onprem.id

  tags = {
    Name = "${var.project_name}-onprem-igw"
  }
}

# Public Subnet (represents a DMZ / bastion tier)
resource "aws_subnet" "onprem_public" {
  vpc_id                  = aws_vpc.onprem.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-onprem-public-subnet"
  }
}

# Private Subnet (where the legacy database server is located)
resource "aws_subnet" "onprem_private" {
  vpc_id            = aws_vpc.onprem.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-onprem-private-subnet"
  }
}

# Route Table for Public Subnet (Routes out to IGW)
resource "aws_route_table" "onprem_public" {
  vpc_id = aws_vpc.onprem.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.onprem.id
  }

  tags = {
    Name = "${var.project_name}-onprem-public-rt"
  }
}

resource "aws_route_table_association" "onprem_public" {
  subnet_id      = aws_subnet.onprem_public.id
  route_table_id = aws_route_table.onprem_public.id
}

# Route Table for Private Subnet
resource "aws_route_table" "onprem_private" {
  vpc_id = aws_vpc.onprem.id

  tags = {
    Name = "${var.project_name}-onprem-private-rt"
  }
}

resource "aws_route_table_association" "onprem_private" {
  subnet_id      = aws_subnet.onprem_private.id
  route_table_id = aws_route_table.onprem_private.id
}
