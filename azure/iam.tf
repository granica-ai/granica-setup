################################################################################
# Admin Server Managed Identity
################################################################################
# The admin server needs a managed identity to run `granica deploy` which
# creates AKS, storage, database, and other Azure resources via Terraform.
################################################################################

resource "azurerm_user_assigned_identity" "admin" {
  name                = "granica-admin-${var.server_name}-mi"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.region
  tags                = local.default_tags
}

################################################################################
# Role Assignments
################################################################################
# The admin identity needs broad permissions to create infrastructure.
# These are scoped to the resource group (not subscription-wide).
################################################################################

# Contributor: create/manage most resources (AKS, VMs, storage, DB, etc.)
resource "azurerm_role_assignment" "admin_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# User Access Administrator: `granica deploy` creates role assignments for the
# workload identities it provisions. Scoped to this resource group so a
# compromised admin VM cannot grant itself roles outside the workload.
resource "azurerm_role_assignment" "admin_user_access" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# In existing-VNet mode the subnets live outside this resource group. `granica
# deploy` creates the Network Contributor assignment on those subnets, which
# requires User Access Administrator on the supplied VNet.
resource "azurerm_role_assignment" "admin_existing_vnet_user_access" {
  count                = local.use_existing_vnet ? 1 : 0
  scope                = var.existing_vnet_id
  role_definition_name = "User Access Administrator"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# Monitoring Contributor: `granica deploy` assigns monitoring roles to the
# workload identities. Scoped to this resource group so the grant cannot reach
# resources outside the workload.
resource "azurerm_role_assignment" "admin_monitoring" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Monitoring Contributor"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# Azure Kubernetes Service Contributor: full AKS cluster management
resource "azurerm_role_assignment" "admin_aks" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Azure Kubernetes Service Contributor Role"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# Azure Kubernetes Service RBAC Cluster Admin: manage RBAC inside AKS
resource "azurerm_role_assignment" "admin_aks_rbac" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# Storage Blob Data Owner: manage blob data (needed to set up containers and test access)
resource "azurerm_role_assignment" "admin_storage" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# TODO (production): Replace broad Contributor role with specific roles:
#   - Azure Kubernetes Service Contributor Role (AKS)
#   - Storage Account Contributor (create storage accounts)
#   - Storage Blob Data Owner (manage blob data)
#   - PostgreSQL Flexible Server Contributor (create/manage DB)
#   - Service Bus Namespace Contributor (create/manage queues)
#   - Network Contributor (manage VNet, subnets, NSGs)
#   - Managed Identity Contributor (create workload identities)

# Managed Identity Operator: assign managed identities to AKS and workload pods
resource "azurerm_role_assignment" "admin_mi_operator" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# Network Contributor: manage VNet, subnets, NSGs, NAT, private endpoints
resource "azurerm_role_assignment" "admin_network" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# In existing-VNet mode the subnets live outside this resource group, so the grant
# above does not reach them. The admin identity's later `granica deploy` creates AKS
# in the supplied subnets and VNet-integrates Postgres, both of which need subnet
# join/read — grant Network Contributor on the supplied VNet so those succeed.
resource "azurerm_role_assignment" "admin_existing_vnet_network" {
  count                = local.use_existing_vnet ? 1 : 0
  scope                = var.existing_vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}

# Private DNS Zone Contributor: manage private DNS zones for private endpoints
resource "azurerm_role_assignment" "admin_private_dns" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.admin.principal_id
}
