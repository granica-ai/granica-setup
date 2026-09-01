variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "region" {
  description = "Azure region (e.g., eastus2, westus2)"
  type        = string
}

variable "package_url" {
  description = "URL to the Granica RPM package"
  type        = string
}

variable "server_name" {
  description = "Suffix for the admin server name and resource group"
  type        = string
  default     = "dev"

  validation {
    condition     = length(var.server_name) <= 15
    error_message = "server_name must be 15 characters or less to avoid Azure naming limits."
  }
}

variable "vm_size" {
  description = "Azure VM size for the admin server"
  type        = string
  default     = "Standard_D2ads_v7"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "granica"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VNet (only used when existing_vnet_id is not set)"
  type        = string
  default     = "10.47.0.0/16"
}

# --- Existing VNet: set existing_vnet_id (and subnets) to deploy into an existing VNet ---

variable "existing_vnet_id" {
  type        = string
  default     = ""
  description = "Resource ID of an existing VNet. When set, deploy into this VNet and set existing_subnet_id. When empty, a new VNet is created."
}

variable "existing_subnet_id" {
  type        = string
  default     = ""
  description = "Resource ID of an existing subnet for the admin server. Required when existing_vnet_id is set."
}

# In existing-VNet mode the module does not create the AKS/private-endpoint
# subnets, but `granica deploy` still needs them (they go into config.tfvars).
# The caller must pre-create and pass them, same as existing_subnet_id.
variable "existing_aks_system_subnet_id" {
  type        = string
  default     = ""
  description = "Resource ID of an existing AKS system/on-demand node subnet. Required when existing_vnet_id is set."
}

variable "existing_aks_workload_subnet_id" {
  type        = string
  default     = ""
  description = "Resource ID of an existing AKS workload/spot node subnet. Required when existing_vnet_id is set."
}

variable "existing_private_endpoints_subnet_id" {
  type        = string
  default     = ""
  description = "Resource ID of an existing subnet for private endpoints (DB/Storage). Must be delegated to Microsoft.DBforPostgreSQL/flexibleServers. Required when existing_vnet_id is set."
}

variable "public_ip_enabled" {
  description = "Assign a public IP to the admin server (dev/test only; use Bastion for production)"
  type        = bool
  default     = false
}

# Default-on secure access, mirroring aws (always-wired SSM Session Manager) and
# gcp (always-wired IAP tunnel): the admin server stays private (no public IP,
# no open SSH) and is reached through the managed tunnel. Azure has no free
# SSM/IAP twin for an interactive shell (`az vm run-command` is command-only),
# so Bastion is that tunnel. Only honored on a module-created VNet; in
# existing-VNet mode the caller brings their own access path.
variable "bastion_enabled" {
  description = "Create an Azure Bastion host for secure SSH access to the admin server (default access path, like SSM on aws / IAP on gcp). Ignored when existing_vnet_id is set."
  type        = bool
  default     = true
}

variable "owner_email" {
  description = "Optional. Email or identifier for the owner tag. Useful when running with a service principal."
  type        = string
  default     = null
}
