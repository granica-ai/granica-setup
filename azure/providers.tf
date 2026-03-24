terraform {
  required_version = "~> 1.13"

  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Provider alias for getting identity (used by data source)
provider "azurerm" {
  alias           = "identity"
  subscription_id = var.subscription_id
  features {}
  # Only register providers we actually use (avoids slow first-run registration of all providers)
  resource_provider_registrations = "none"
}

# Get current Azure caller identity for default tags
data "azurerm_client_config" "current" {
  provider = azurerm.identity
}

locals {
  owner_for_tag = coalesce(var.owner_email, data.azurerm_client_config.current.object_id)
  default_tags = {
    admin_server_name = "granica-admin-server-${var.server_name}"
    owner_id          = local.owner_for_tag
    managed_by        = "terraform"
    project           = "granica"
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
  # Only register providers we actually use (avoids slow first-run registration of all providers)
  resource_provider_registrations = "none"
}
