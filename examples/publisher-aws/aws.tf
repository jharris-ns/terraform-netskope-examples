# =============================================================================
# AWS Infrastructure
# =============================================================================
# Publishers in private subnets with NAT Gateway for outbound connectivity

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${var.publisher_name}-vpc" }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.publisher_name}-igw" }
}

# =============================================================================
# Public Subnet (for NAT Gateway)
# =============================================================================

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = false

  tags = { Name = "${var.publisher_name}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${var.publisher_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# NAT Gateway
# =============================================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "${var.publisher_name}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = { Name = "${var.publisher_name}-nat" }

  depends_on = [aws_internet_gateway.this]
}

# =============================================================================
# Private Subnet (for Publisher)
# =============================================================================

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.this.id
  cidr_block = var.private_subnet_cidr

  tags = { Name = "${var.publisher_name}-private" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = { Name = "${var.publisher_name}-private-rt" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# Security Group - Outbound only
# =============================================================================

resource "aws_security_group" "publisher" {
  name        = "${var.publisher_name}-sg"
  description = "Netskope Publisher - outbound only"
  vpc_id      = aws_vpc.this.id

  # No ingress rules - no inbound traffic allowed

  egress {
    description = "HTTPS to Netskope NewEdge"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.publisher_name}-sg" }
}

# =============================================================================
# EC2 Instance in Private Subnet
# =============================================================================

resource "aws_instance" "publisher" {
  ami                    = data.aws_ami.netskope_publisher.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.publisher.id]

  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    /opt/netskope/npa-publisher-wizard -token ${netskope_npa_publisher_token.this.token}
  EOF
  )

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Enforce IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = { Name = var.publisher_name }

  lifecycle {
    ignore_changes = [ami]
  }
}
