variable "aws_region" {
  description = "AWS region"
  type        = string
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

variable "deploy_emr" {
  type    = bool
  default = false
}

// Place admin-server in public subnet with a public IP
variable "public_ip_enabled" {
  type    = bool
  default = false
}

variable "server_name" {
  description = "Suffix for the admin server instance name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.47.0.0/16"
  description = "The CIDR block for the VPC (only used when use_existing_vpc is false)"
}

# --- Existing VPC (use_existing_vpc = true) ---

variable "use_existing_vpc" {
  type        = bool
  default     = false
  description = "When true, deploy into an existing VPC instead of creating a new one. Set vpc_id and existing_private_subnet_ids (and existing_public_subnet_ids if public_ip_enabled)."
}

variable "existing_vpc_id" {
  type        = string
  default     = ""
  description = "ID of the existing VPC. Required when use_existing_vpc is true."

  validation {
    condition     = !var.use_existing_vpc || length(var.existing_vpc_id) > 0
    error_message = "existing_vpc_id must be set when use_existing_vpc is true."
  }
}

variable "existing_private_subnet_ids" {
  type        = list(string)
  default     = []
  description = "IDs of existing private subnets. Required when use_existing_vpc is true. Admin server is placed in the first subnet unless public_ip_enabled."

  validation {
    condition     = !var.use_existing_vpc || length(var.existing_private_subnet_ids) > 0
    error_message = "existing_private_subnet_ids must have at least one subnet when use_existing_vpc is true."
  }
}

variable "existing_public_subnet_ids" {
  type        = list(string)
  default     = []
  description = "IDs of existing public subnets. Required when use_existing_vpc is true and public_ip_enabled is true."

  validation {
    condition     = !(var.use_existing_vpc && var.public_ip_enabled) || length(var.existing_public_subnet_ids) > 0
    error_message = "existing_public_subnet_ids must have at least one subnet when use_existing_vpc and public_ip_enabled are both true."
  }
}

# --- Optional: skip creating resources that may already exist ---

variable "create_s3_vpc_endpoint" {
  type        = bool
  default     = null
  description = "Set to false to skip creating the S3 Gateway VPC endpoint (e.g. VPC already has one; avoids RouteAlreadyExists). When null, defaults to false if use_existing_vpc is true, else true."
}

variable "create_instance_connect_endpoint" {
  type        = bool
  default     = true
  description = "Set to false to skip creating an EC2 Instance Connect Endpoint (e.g. subnet quota reached or you use an existing EIC). When false, set existing_eice_security_group_id so the admin server allows ingress from that SG."
}

variable "existing_eice_security_group_id" {
  type        = string
  default     = ""
  description = "Security group ID of an existing EC2 Instance Connect Endpoint (or SSM). Required when create_instance_connect_endpoint is false so the admin server allows connectivity."

  validation {
    condition     = var.create_instance_connect_endpoint || length(var.existing_eice_security_group_id) > 0
    error_message = "existing_eice_security_group_id must be set when create_instance_connect_endpoint is false."
  }
}
