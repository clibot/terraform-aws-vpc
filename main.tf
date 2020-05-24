# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name = var.name
  }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "this" {
  vpc = var.enable_eip
}

# Route tables

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private-route-table" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-public-route-table" }
}

# public

resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id               = aws_vpc.this.id
  cidr_block           = var.public_subnets[count.index]
  availability_zone_id = var.azs[count.index]

  tags = {
    Name = "${var.name}-${var.azs[count.index]}"
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# private

resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id               = aws_vpc.this.id
  cidr_block           = var.public_subnets[count.index]
  availability_zone_id = var.azs[count.index]

  tags = {
    Name = "${var.name}-${var.azs[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Gateways

resource "aws_nat_gateway" "this" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  allocation_id = aws_eip.this.id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name}-nat-gateway"
  }
}

resource "aws_internet_gateway" "this" {
  count = length(var.public_subnets) > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-internet-gateway"
  }
}

# Routes

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.this[0].id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route" "private" {
  route_table_id         = aws_route_table.private.id
  nat_gateway_id         = aws_nat_gateway.this[0].id
  destination_cidr_block = "0.0.0.0/0"
}
