variable "project_id" {
  description = "The ID of the project in which to create resources."
  type        = string
}

variable "region" {
  description = "The region in which to create resources."
  type        = string
}

variable "zone" {
  description = "The zone in which to create resources."
  type        = string
}
variable "boot_image" {
  type        = string
  description = "The admin server's boot image"
  default     = "centos-cloud/centos-stream-9"
}

variable "admin_image_uri" {
  description = "Image URI for the Granica admin server"
  type        = string
  default     = "projects/granica-customer-resources/global/images/family/granica-admin"
}

variable "package_url" {
  type        = string
  description = "URL of the Project N package to install on launch"
}

variable "granica_username" {
  type        = string
  description = "Name of the Granica user"
  default     = "granica"
}

variable "machine_type" {
  type        = string
  description = "GCP machine type for the admin server"
  default     = "e2-small"
}

variable "server_name" {
  description = "Suffix for the admin server instance name"
  type        = string
  default     = "dev"

  validation {
    condition     = length(var.server_name) <= 15
    error_message = "server_name must be 15 characters or less to avoid GCP naming limits."
  }
}
