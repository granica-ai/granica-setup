terraform {
  required_version = "~> 1.13"

  backend "s3" {
    # These are dev defaults that can be overridden by backend.conf in production
    bucket = "kry-ci-granica-setup-terraform-state"
    region = "us-east-2"
    key    = "dev"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.32"
    }
    # NOTE: kubernetes (2.29.0) and kubectl (gavinbunney 1.14.0) were removed --
    # no resources in this repo use them. They are declared in the downstream
    # project-n deployment, not in the admin server bootstrap.
  }
}

# Provider alias for getting identity (used by data source)
provider "aws" {
  alias  = "identity"
  region = var.aws_region
}

# Get current AWS caller identity for default tags
data "aws_caller_identity" "current" {
  provider = aws.identity
}

locals {
  default_tags = {
    admin_server_name         = "granica-admin-server-${var.server_name}"
    owner_id                  = data.aws_caller_identity.current.user_id
    owner_arn                 = data.aws_caller_identity.current.arn
    (var.ec2_resource_tag_key) = var.ec2_resource_tag_value
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.default_tags
  }
}
