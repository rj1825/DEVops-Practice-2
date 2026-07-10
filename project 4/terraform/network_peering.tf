# VPC Peering Connection between On-Premises and AWS Cloud VPCs
resource "aws_vpc_peering_connection" "peer" {
  peer_vpc_id = aws_vpc.cloud.id
  vpc_id      = aws_vpc.onprem.id
  auto_accept = true

  tags = {
    Name = "${var.project_name}-vpc-peering"
  }
}

# Cross-VPC Route: Route on-prem private subnet traffic bound for Cloud CIDR through the Peering Connection
resource "aws_route" "onprem_to_cloud" {
  route_table_id            = aws_route_table.onprem_private.id
  destination_cidr_block    = aws_vpc.cloud.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# Cross-VPC Route: Route on-prem public subnet traffic (where legacy EC2 resides) bound for Cloud CIDR
resource "aws_route" "onprem_public_to_cloud" {
  route_table_id            = aws_route_table.onprem_public.id
  destination_cidr_block    = aws_vpc.cloud.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}

# Cross-VPC Route: Route Cloud subnet traffic bound for On-Premises CIDR through the Peering Connection
resource "aws_route" "cloud_to_onprem" {
  route_table_id            = aws_route_table.cloud_private.id
  destination_cidr_block    = aws_vpc.onprem.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
}
