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

variable "airflow_enabled" {
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
  description = "The CIDR block for the VPC (only used when existing_vpc_id is not set)"
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
}

variable "existing_public_subnet_ids" {
  type        = list(string)
  default     = []
  description = "IDs of existing public subnets. Required when existing_vpc_id is set and public_ip_enabled is true."
}

# --- Optional: skip creating resources that may already exist ---

variable "create_s3_vpc_endpoint" {
  type        = bool
  default     = null
  description = "Set to false to skip creating the S3 Gateway VPC endpoint (e.g. VPC already has one; avoids RouteAlreadyExists). When null, defaults to false if existing_vpc_id is set, else true."
}

variable "instance_connect" {
  type        = string
  default     = ""
  description = <<-EOT
    Single knob for Instance Connect–style access (Session Manager remains available in all cases via the instance profile):
    - Leave empty (default): do not create an Instance Connect Endpoint; use Session Manager or your own path.
    - "create": create a new EC2 Instance Connect Endpoint and its security group.
    - A value starting with "sg-": do not create an endpoint; allow admin ingress from that security group (e.g. an existing Instance Connect endpoint or bastion).
  EOT

  validation {
    condition = (
      trimspace(var.instance_connect) == "" ||
      lower(trimspace(var.instance_connect)) == "create" ||
      startswith(lower(trimspace(var.instance_connect)), "sg-")
    )
    error_message = "instance_connect must be empty, \"create\", or a security group id starting with sg- (case-insensitive)."
  }
}
