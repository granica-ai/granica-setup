terraform {
  required_version = "1.11.1"

  backend "s3" {
    # These are dev defaults that can be overridden by backend.conf in production
    bucket = "kry-ci-granica-setup-terraform-state"
    region = "us-east-2"
    key    = "dev"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.45.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.29.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
