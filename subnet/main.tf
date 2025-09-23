terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.8.0"
    }
  }
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "terraform_remote_state" "vpc" {

  backend = "remote"
  config = {
    hostname = "app.terraform.io"
    organization = "daily-ops"
    workspaces = {
      name = "aws-vpc"
    }
  }

}

data "aws_vpc" "my_vpc" {
  id = data.terraform_remote_state.vpc.outputs.vpc_id
}

locals {
  azs          = data.aws_availability_zones.available.names
  subnet_prefix = "${element(split(".", data.aws_vpc.my_vpc.cidr_block),0)}.${element(split(".", data.aws_vpc.my_vpc.cidr_block),1)}"
  public_subnets      = { for i, az in local.azs : az => "${local.subnet_prefix}.${local.subnet_start_idx + i}.0/24" }
  private_subnets      = { for i, az in local.azs : az => "${local.subnet_prefix}.${local.subnet_start_idx + i+10}.0/24" }
  subnet_start_idx = 1
}

resource "aws_subnet" "public" {
  for_each          = toset(local.azs)
  vpc_id            = data.aws_vpc.my_vpc.id
  cidr_block        = local.public_subnets[each.key]
  availability_zone = each.key

  map_public_ip_on_launch = true

  tags = {
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}-public"
    zone = "public"
    Group = data.terraform_remote_state.vpc.outputs.build_id
  }
}

resource "aws_subnet" "private" {
  for_each          = toset(local.azs)
  vpc_id            = data.aws_vpc.my_vpc.id
  cidr_block        = local.private_subnets[each.key]
  availability_zone = each.key

  map_public_ip_on_launch = false

  tags = {
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}-private"
    zone = "private"
    Group = data.terraform_remote_state.vpc.outputs.build_id
  }
}


resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.my_vpc.id
  tags = {
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}-private"
    zone = "private"
    Group = data.terraform_remote_state.vpc.outputs.build_id
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private
  subnet_id = each.value.id
  route_table_id = aws_route_table.private.id
}


resource "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.my_vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  policy = <<EOS
{
        Version : "2008-10-17",
        Statement :  [
          {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Action": [
              "s3:DeleteObject",
              "s3:GetObject",
              "s3:PutObject",
              "s3:ReplicateObject",
              "s3:RestoreObject"
            ],
            "Resource": "*"
          }
        ]
}
EOS

  tags = {
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}"
    Group = data.terraform_remote_state.vpc.outputs.build_id
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  route_table_id  = aws_route_table.private.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

output "public_subnets" {
  value = { for s in aws_subnet.public : s.availability_zone => s.id }
}

output "private_subnets" {
  value = { for s in aws_subnet.private : s.availability_zone => s.id }
}

output "private_route_table" {
  value = aws_route_table.private.id
}

output "s3_private_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "s3_private_endpoint_arn" {
  value = aws_vpc_endpoint.s3.arn
}