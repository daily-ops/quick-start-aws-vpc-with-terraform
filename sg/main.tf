terraform {
    required_version = "~> 1.5"
    required_providers {
            aws = {
                source = "hashicorp/aws"
                version = "~> 5.8.0"
            }

    }
}

data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "../vpc/terraform.tfstate"
  }
}

resource "aws_security_group" "public" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  name   = "public"
}

resource "aws_security_group_rule" "public-ssh" {
  security_group_id = aws_security_group.public.id

  type        = "ingress"
  protocol    = "tcp"
  from_port   = 22
  to_port     = 22
  cidr_blocks = ["0.0.0.0/0"]

    description = "SSH"

}


resource "aws_security_group_rule" "egress-to-private" {
  security_group_id = aws_security_group.public.id

  type = "egress"
  protocol = -1
  from_port = 0
  to_port = 0
  source_security_group_id = aws_security_group.private.id
}

resource "aws_security_group_rule" "egress-to-world" {
  security_group_id = aws_security_group.public.id

  type = "egress"
  protocol = -1
  from_port = 0
  to_port = 0
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_security_group" "private" {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
  name   = "private"
}

resource "aws_security_group_rule" "postgres" {
    security_group_id = aws_security_group.private.id

    type = "ingress"
    protocol = "tcp"
    from_port = 5432
    to_port = 5432
    source_security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "private-ssh" {
    security_group_id = aws_security_group.private.id

    type = "ingress"
    protocol = "tcp"
    from_port = 22
    to_port = 22
    source_security_group_id = aws_security_group.public.id
}

output "public_sg_id" {
    value = aws_security_group.public.id
}

output "private_sg_id" {
    value = aws_security_group.private.id
}