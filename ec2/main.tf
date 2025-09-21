terraform {
  required_version = "~> 1.5.0"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.8.0"
    }
  }
}

variable "ssh_key_name" {
    description = "The name of the SSH key pair to access the EC2 instances"
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

data "terraform_remote_state" "iam" {

  backend = "remote"
  config = {
    hostname = "app.terraform.io"
    organization = "daily-ops"
    workspaces = {
      name = "aws-computes-iam"
    }
  }
}

data "aws_ami" "ubuntu_22_04" {
    most_recent = true

    owners = ["099720109477"]

    filter {
        name = "name"
        values = ["ubuntu-minimal/images/hvm-ssd/ubuntu-jammy-22.04-amd64-minimal-*"]
    }
}

resource "aws_iam_instance_profile" "public" {
    name = "public-ec2-profile"
    role = keys(data.terraform_remote_state.iam.outputs.public-ec2-role)[0]
}

resource "aws_instance" "public" {
    for_each = data.terraform_remote_state.vpc.outputs.public_subnets
    ami = data.aws_ami.ubuntu_22_04.id
    instance_type = "t2.micro"
    availability_zone = each.key
    subnet_id = each.value
    key_name = var.ssh_key_name
    vpc_security_group_ids = [data.terraform_remote_state.sg.outputs.public_sg_id]
    user_data = <<-EOF
        #!/bin/bash
        sudo apt update
        sudo apt install -y awscli
    EOF
    iam_instance_profile = aws_iam_instance_profile.public.name
}

resource "aws_instance" "private" {
    for_each = data.terraform_remote_state.vpc.outputs.private_subnets
    ami = data.aws_ami.ubuntu_22_04.id
    instance_type = "t2.micro"
    availability_zone = each.key
    subnet_id = each.value
    key_name = var.ssh_key_name
    vpc_security_group_ids = [data.terraform_remote_state.sg.outputs.private_sg_id]
}

output "my_ec2_public_ips" {
    value = { for i in aws_instance.public: i.availability_zone => i.public_ip }
}

output "my_ec2_private_ips" {
    value = { for i in aws_instance.private: i.availability_zone => i.private_ip }
}
