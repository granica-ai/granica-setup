variable "aws_region" {
  description = "AWS region"
}

variable "vpc_cidr_prefix" {
  description = "CIDR block for the VPC"
  default     = "10.47"
}

variable "package_url" {
  description = "URL to the granica package"
  type        = string
}

// This var is from project-n-setup
variable "manage_vpc" {
  type    = bool
  default = true
}

// Place admin-server in public subnet with a public IP
variable "public_ip_enabled" {
  type    = bool
  default = false
}
