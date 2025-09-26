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
               "Resource": "*"
            }
        ]
    }
    EOF
}

resource "aws_iam_policy_attachment" "public-ec2-role-attachement" {
    name = "tfc-computes-public-zone-role-attachment"
    policy_arn = aws_iam_policy.public-ec2-policy.arn
    roles = [
        aws_iam_role.public-ec2-role.id,
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ]
}


resource "aws_iam_role" "private-ec2-role" {
  name               = "tfc-computes-private-zone-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_policy" "private-ec2-policy" {
    name      = "tfc-computes-private-zone-policy"
    policy    = <<-EOF
    {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Action": [
                    "s3:ListAccessPointsForObjectLambda",
                    "s3:GetObjectRetention",
                    "s3:GetAccessPointPolicyStatusForObjectLambda",
                    "s3:GetAccessPointPolicyForObjectLambda",
                    "s3:GetObjectVersionTagging",
                    "s3:GetObjectAttributes",
                    "s3:GetObjectLegalHold",
                    "s3:GetAccessPointConfigurationForObjectLambda",
                    "s3:GetObjectVersionAttributes",
                    "s3:GetObjectVersionTorrent",
                    "s3:GetBucketObjectLockConfiguration",
                    "s3:PutObject",
                    "s3:GetObjectAcl",
                    "s3:GetObject",
                    "s3:GetObjectTorrent",
                    "s3:GetObjectVersionAcl",
                    "s3:GetObjectTagging",
                    "s3:GetObjectVersionForReplication",
                    "s3:DeleteObject",
                    "s3:GetAccessPointForObjectLambda",
                    "s3:GetObjectVersion",
                    "s3:ListBucket"
               ],
               "Resource": "*"
            }
        ]
    }
    EOF
}

resource "aws_iam_policy_attachment" "private-ec2-role-attachement" {
    name = "tfc-computes-private-zone-role-attachment"
    policy_arn = aws_iam_policy.private-ec2-policy.arn
    roles = [
        aws_iam_role.private-ec2-role.id,
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ]
}

output "public-ec2-role" {
    value = { 
        "${aws_iam_role.public-ec2-role.name}" = "${aws_iam_role.public-ec2-role.arn}"
    }
}

output "private-ec2-role" {
    value = { 
        "${aws_iam_role.private-ec2-role.name}" = "${aws_iam_role.private-ec2-role.arn}"
    }
}