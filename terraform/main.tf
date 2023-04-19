
#resource "aws_instance" "example" {
#  ami = "ami-064eb0bee0c5402c5"
#  instance_type = "t2.micro"
#
#  tags = {
#    Name = "my-ec2-testing"
#  }
#}

#resource "aws_s3_bucket" "my-bucket" {
#  bucket = "my-bucket-name-testing"
#}

variable "stack_name" {
  type = string
  default = "terraform"
}

variable "aws_region" {
  default = "ap-southeast-1"
}

variable "aws_profile" {
  default = "default"
}

variable "public_ips" {
  type = map(string)
  default = {
    "instance1" = "1.2.3.4"
    "instance2" = "5.6.7.8"
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

#resource "aws_s3_bucket" "my-bucket" {
#  bucket = "my-bucket-name-testing"
#}

//S3
module "s3" {
  source           = "./modules/s3"
  stack_name       = var.stack_name
}

// VPC
module "vpc" {
  source = "./modules/vpc"
  stack_name = var.stack_name
}

// vm
module "ec2" {
  source           = "./modules/ec2"
  stack_name       = var.stack_name
  vpc_id           = module.vpc.vpc_id
  public_ips       = var.public_ips
  public_subnet_id = module.vpc.public_subnet_ids[0]
  s3_bucket_arn    = module.s3.s3_bucket_arn
}
