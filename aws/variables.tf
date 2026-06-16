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

# IAM role / policy naming + permission boundary controls.
# These mirror the same-named variables in krypton (MR !1987) so the deployer's
# roles/policies follow the customer's naming convention, and the deployer is
# scoped to manage IAM in that same namespace (see locals in iam.tf).
variable "role_name_prefix" {
  type        = string
  default     = ""
  description = "Prefix prepended to every IAM role name created by this module (e.g. \"CustomerManaged-\")."
}

variable "role_path" {
  type        = string
  default     = "/"
  description = "IAM path for every IAM role created by this module (e.g. \"/OneCloud/\"). Must start and end with \"/\"."

  validation {
    condition     = can(regex("^/(.*/)?$", var.role_path))
    error_message = "role_path must start and end with \"/\" (e.g. \"/\" or \"/OneCloud/\")."
  }
}

variable "policy_name_prefix" {
  type        = string
  default     = ""
  description = "Prefix prepended to every IAM policy name created by this module (e.g. \"CustomerManaged_\"). Configured separately from role_name_prefix."
}

variable "policy_path" {
  type        = string
  default     = "/"
  description = "IAM path for every IAM policy created by this module (e.g. \"/\"). Must start and end with \"/\"."

  validation {
    condition     = can(regex("^/(.*/)?$", var.policy_path))
    error_message = "policy_path must start and end with \"/\" (e.g. \"/\")."
  }
}

variable "permission_boundary_arn" {
  type        = string
  default     = ""
  description = "ARN of an existing IAM policy to attach as the permissions boundary on IAM roles created by this module. Empty string means no boundary."
}

variable "permission_boundary_on_admin_role" {
  type        = bool
  default     = true
  description = <<-EOT
    Whether to attach permission_boundary_arn to the admin (deployer) role itself.
    On by default. Note: the admin role must create IAM roles/policies during
    deployment, so the configured boundary must permit the deployer's iam/ec2/eks
    write actions; set this false if the boundary would otherwise block them.
  EOT
}

# BYO admin role. When set, the admin (deployer) role and everything that defines
# it — instance profile, deploy/vpc/emr/efs policies, attachments — are not created.
# The customer pre-creates a role with equivalent permissions (e.g. under a
# restrictive permission boundary that blocks role creation), and the admin server
# EC2 instance uses custom_admin_instance_profile_name.
variable "custom_admin_role_arn" {
  type        = string
  default     = ""
  description = "If set, use this pre-existing IAM role for the admin (deployer) server instead of creating one. Skips the admin role, its instance profile, policies, and attachments. Requires custom_admin_instance_profile_name."
}

variable "custom_admin_instance_profile_name" {
  type        = string
  default     = ""
  description = "Name of a pre-existing instance profile (wrapping custom_admin_role_arn) attached to the admin server EC2 instance. Required when custom_admin_role_arn is set."
}
