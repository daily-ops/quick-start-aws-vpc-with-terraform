terraform {
  required_version = "~> 1.5"
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.8.0"
    }
  }
}

resource "aws_iam_role" "public-ec2-role" {
  name               = "tfc-computes-public-zone-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "assume_role" {
    statement {
        actions = ["sts:AssumeRole"]

        principals {
            type = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_policy" "public-ec2-policy" {
    name      = "tfc-computes-public-zone-policy"
    policy    = <<-EOF
    {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
               "s3:GetObject",
               "s3:ListBucket",
               "s3:ListAllMyBuckets"
               ],
               "Resource": "*"}]
    }
    EOF
}

resource "aws_iam_policy_attachment" "public-ec2-role-attachement" {
    name = "tfc-computes-public-zone-role-attachment"
    policy_arn = aws_iam_policy.public-ec2-policy.arn
    roles = [aws_iam_role.public-ec2-role.id]
}

output "public-ec2-role" {
    value = { 
        "${aws_iam_role.public-ec2-role.name}" = "${aws_iam_role.public-ec2-role.arn}"
    }
}