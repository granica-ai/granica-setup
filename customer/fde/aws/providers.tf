terraform {
  required_version = "1.13.4"

  backend "s3" {
    # These are dev defaults that can be overridden by backend.conf in production
    bucket = "kry-ci-granica-setup-terraform-state"
    region = "us-west-2"
    key    = "dev"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.45.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
