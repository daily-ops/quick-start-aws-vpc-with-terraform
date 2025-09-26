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

data "terraform_remote_state" "sg" {

  backend = "remote"
  config = {
    hostname = "app.terraform.io"
    organization = "daily-ops"
    workspaces = {
      name = "aws-security-group"
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
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}-public-${each.key}"
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
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}-private-${each.key}"
    zone = "private"
    Group = data.terraform_remote_state.vpc.outputs.build_id
  }
}


resource "aws_route_table" "private" {
  for_each = toset(local.azs)
  
  vpc_id = data.aws_vpc.my_vpc.id
  tags = {
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}-rt-private"
    zone = "private"
    Group = data.terraform_remote_state.vpc.outputs.build_id
  }
}

resource "aws_route_table_association" "private" {
  for_each = toset(local.azs)
  subnet_id = "${aws_subnet.private[each.key].id}"
  route_table_id = "${aws_route_table.private[each.key].id}"
}


resource "aws_vpc_endpoint" "s3" {
  vpc_id       = data.aws_vpc.my_vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  policy = <<-EOS
{
        "Version" : "2008-10-17",
        "Statement" :  [
          {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Principal": "*",
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
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}-s3"
    Group = data.terraform_remote_state.vpc.outputs.build_id
  }
}

resource "aws_vpc_endpoint_route_table_association" "s3" {
  for_each = toset(local.azs)
  route_table_id  = "${aws_route_table.private[each.key].id}"
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id       = data.aws_vpc.my_vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.ssm"
  policy = <<-EOS
{
        "Version" : "2008-10-17",
        "Statement" :  [
          {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "*",
            "Resource": "*"
          }
        ]
}
EOS

  vpc_endpoint_type = "Interface"

  security_group_ids = [
    data.terraform_remote_state.sg.outputs.private_sg_id
  ]

  subnet_ids = [for subnet in aws_subnet.private: subnet.id]

  private_dns_enabled = true
  tags = {
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}-ssm"
    Group = data.terraform_remote_state.vpc.outputs.build_id
  }
}


resource "aws_vpc_endpoint" "ssm-session" {
  vpc_id       = data.aws_vpc.my_vpc.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  policy = <<-EOS
{
        "Version" : "2008-10-17",
        "Statement" :  [
          {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "*",
            "Resource": "*"
          }
        ]
}
EOS

  vpc_endpoint_type = "Interface"

  security_group_ids = [
    data.terraform_remote_state.sg.outputs.private_sg_id
  ]

  subnet_ids = [for subnet in aws_subnet.private: subnet.id]

  private_dns_enabled = true
  tags = {
    Name = "tf-managed-${data.terraform_remote_state.vpc.outputs.build_id}-ssm-ssmmessages"
    Group = data.terraform_remote_state.vpc.outputs.build_id
  }
}

# resource "aws_route" "ssm-session" {
#   for_each = toset(local.azs)
#   route_table_id            = "${aws_route_table.private[each.key].id}"
#   network_interface_id = "${aws_vpc_endpoint.ssm-session.network_interface_ids[index(local.azs, each.key)]}"
# }

output "public_subnets" {
  value = { for s in aws_subnet.public : s.availability_zone => s.id }
}

output "private_subnets" {
  value = { for s in aws_subnet.private : s.availability_zone => s.id }
}

output "private_route_tables" {
  value = [ for rt in aws_route_table.private : rt.id ]
}

output "s3_private_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "s3_private_endpoint_arn" {
  value = aws_vpc_endpoint.s3.arn
}