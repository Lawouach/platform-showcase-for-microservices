variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/terraform.pub
DESCRIPTION
}

variable "key_name" {
  description = "Desired name of AWS key pair"
}

variable "credentials_profile" {
  description = "AWS credentials profile"
  default = "showcase"
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default = "eu-west-1"
}

variable "aws_availability_zone" {
  description = "AWS availability zone to launch servers."
  default = "eu-west-1a"
}

# CentOS 7 (x86_64) with Updates HVM
variable "aws_amis" {
  default = {
    eu-west-1 = "ami-7abd0209"
    us-east-1 = "ami-6d1c2007"
    us-west-1 = "ami-d2c924b2"
    us-west-2 = "ami-af4333cf"
  }
}

variable "aws_slave_instance_size" {
  description = "EC2 instance size"
  default = "t2.medium"
}

variable "public_subnet_cidr" {
  default = "10.0.5.0/24"
}

variable "private_subnet_cidr" {
  default = "10.0.12.0/24"
}

variable "domain" {
  default = "service.consul"
}