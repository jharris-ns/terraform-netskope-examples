terraform {
  required_version = ">= 1.0"

  required_providers {
    netskope = {
      source  = "netskopeoss/netskope"
      version = ">= 0.3.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Netskope provider - uses environment variables
provider "netskope" {
  server_url = var.netskope_server_url
  api_key    = var.netskope_api_key
}

# AWS provider with SSO authentication
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# Find the latest Netskope Publisher AMI
data "aws_ami" "netskope_publisher" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["*Netskope Private Access Publisher*"]
  }
}
