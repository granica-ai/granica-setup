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
  type        = bool
  default     = false
  description = "When true, attaches EMR IAM policy to the admin server role so the EC2 instance can launch and manage EMR clusters (e.g. via Terraform or CLI from the admin server). Set to true if you use this admin server to run terraform-aws-emr or create EMR clusters."
}

variable "airflow_enabled" {
  type        = bool
  default     = false
  description = "Deprecated: EFS policy was removed; this variable is ignored. Kept for backward compatibility with existing tfvars."
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
  description = "The CIDR block for the VPC (only used when existing_vpc_id is not set)"
}

# Tag used to scope EC2 CreateTags/DeleteTags and Describe* to managed resources only.
variable "ec2_resource_tag_key" {
  type        = string
  default     = "ManagedBy"
  description = "Tag key used to identify EC2/VPC resources managed by this stack. CreateTags is allowed only when the request includes this tag; DeleteTags only on resources that have this tag."
}
variable "ec2_resource_tag_value" {
  type        = string
  default     = "granica"
  description = "Tag value for ec2_resource_tag_key. Must match tags applied to EC2/VPC resources created or managed by this stack."
}

# --- Existing VPC: set existing_vpc_id (and subnets) to deploy into an existing VPC ---

variable "existing_vpc_id" {
  type        = string
  default     = ""
  description = "ID of an existing VPC. When set, deploy into this VPC and set existing_private_subnet_ids (and existing_public_subnet_ids if public_ip_enabled). When empty, a new VPC is created."
}

variable "existing_private_subnet_ids" {
  type        = list(string)
  default     = []
  description = "IDs of existing private subnets. Required when existing_vpc_id is set. Admin server is placed in the first subnet unless public_ip_enabled."

  validation {
    condition     = length(var.existing_vpc_id) == 0 || length(var.existing_private_subnet_ids) > 0
    error_message = "existing_private_subnet_ids must have at least one subnet when existing_vpc_id is set."
  }
}

variable "existing_public_subnet_ids" {
  type        = list(string)
  default     = []
  description = "IDs of existing public subnets. Required when existing_vpc_id is set and public_ip_enabled is true."

  validation {
    condition     = length(var.existing_vpc_id) == 0 || !var.public_ip_enabled || length(var.existing_public_subnet_ids) > 0
    error_message = "existing_public_subnet_ids must have at least one subnet when existing_vpc_id is set and public_ip_enabled is true."
  }
}

# --- Optional: skip creating resources that may already exist ---

variable "create_s3_vpc_endpoint" {
  type        = bool
  default     = null
  description = "Set to false to skip creating the S3 Gateway VPC endpoint (e.g. VPC already has one; avoids RouteAlreadyExists). When null, defaults to false if existing_vpc_id is set, else true."
}

variable "existing_eice_security_group_id" {
  type        = string
  default     = ""
  description = "When set, do not create an EC2 Instance Connect Endpoint; allow admin server ingress from this SG (existing EIC or SSM). When empty, an EIC is created."
}
