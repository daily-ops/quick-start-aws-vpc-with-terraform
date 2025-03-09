resource "aws_vpc" "my_vpc" {
  cidr_block = "10.1.0.0/16"

  tags = {
    name = "${random_string.prefix.result}-custom-vpc"
  }
}

resource "random_string" "prefix" {
  length = 6
  special = false
  upper = false
  numeric = false
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs          = data.aws_availability_zones.available.names
  public_subnets      = { for i, az in local.azs : az => "10.1.${local.subnet_start_idx + i}.0/24" }
  private_subnets      = { for i, az in local.azs : az => "10.1.${local.subnet_start_idx + i+10}.0/24" }
  subnet_start_idx = 0
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8.0"
    }

    random = {
      source = "hashicorp/random"
      version = "~> 3.7.0"
    }
  }
}

resource "aws_subnet" "public" {
  for_each          = toset(local.azs)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = local.public_subnets[each.key]
  availability_zone = each.key

  map_public_ip_on_launch = true

  tags = {
    Name = "${random_string.prefix.result}-public"
    zone = "public"
  }
}

resource "aws_subnet" "private" {
  for_each          = toset(local.azs)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = local.private_subnets[each.key]
  availability_zone = each.key

  map_public_ip_on_launch = false

  tags = {
    Name = "${random_string.prefix.result}-private"
    zone = "private"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "${random_string.prefix.result}-custom-vpc"
  }
}

data "aws_route_table" "main" {
  filter {
    name = "association.main"
    values = ["true"]
  }

  filter {
    name = "vpc-id"
    values = [aws_vpc.my_vpc.id]
  }
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route" "default" {
  route_table_id = data.aws_route_table.main.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "${random_string.prefix.result}-private"
    zone = "private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private
  subnet_id = each.value.id
  route_table_id = aws_route_table.private.id
}

output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "public_subnets" {
  value = { for s in aws_subnet.public : s.availability_zone => s.id }
}

output "private_subnets" {
  value = { for s in aws_subnet.private : s.availability_zone => s.id }
}

output "main_route_table" {
  value = data.aws_route_table.main.id
}

output "private_route_table" {
  value = aws_route_table.private.id
}
