# Build a custom VPC with Terraform

Having Terraform configuration broken down into multiple groups to promote collaboration across teams.

Each sub-directory can be implemented in parallel as long as it knows the requried input, such as vpc id, subnet id, security group id, iam role name, for example.

```
data "terraform_remote_state" "vpc" {
  backend = "local"
  config = {
    path = "../vpc/terraform.tfstate"
  }
}
```

## Pre-requisites

- Fundamental knowledge in AWS infrastructure
- The configuraton uses Terraform 1.5, and AWS 5.8

## VPC

It creates VPC, private and public subnets, internet gateway. There is no [NAT gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway). It cost money and can be done by yourself. :-D

## Security Group

Security groups and rules just for SSH using source security group id between private and public subnets.

## IAM role

IAM role for instance profile

## EC2

It creates EC2 instances, one for each az and subnet with instance type t2.micro consuming the instance profile from [iam](./iam). The ec2 will have aws cli install via the userdata and the profile should allow the s3 list buckets operation. It also requires `ssh_key_name` input for ssh access.
