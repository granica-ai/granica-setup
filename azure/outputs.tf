output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "The ID of the VNet"
  value       = local.vnet_id
}

output "admin_subnet_id" {
  description = "The ID of the admin subnet"
  value       = local.admin_subnet_id
}

output "aks_system_subnet_id" {
  description = "The ID of the AKS system node subnet"
  value       = local.use_existing_vnet ? "NOT_CREATED" : azurerm_subnet.aks_system[0].id
}

output "aks_workload_subnet_id" {
  description = "The ID of the AKS workload/spot node subnet"
  value       = local.use_existing_vnet ? "NOT_CREATED" : azurerm_subnet.aks_workload[0].id
}

output "private_endpoints_subnet_id" {
  description = "The ID of the private endpoints subnet"
  value       = local.use_existing_vnet ? "NOT_CREATED" : azurerm_subnet.private_endpoints[0].id
}

output "instance_id" {
  description = "The resource ID of the admin server VM"
  value       = azurerm_linux_virtual_machine.admin.id
}

output "admin_identity_client_id" {
  description = "The client ID of the admin server managed identity"
  value       = azurerm_user_assigned_identity.admin.client_id
}

output "admin_identity_principal_id" {
  description = "The principal ID of the admin server managed identity"
  value       = azurerm_user_assigned_identity.admin.principal_id
}

output "private_ip" {
  description = "The private IP address of the admin server"
  value       = azurerm_network_interface.admin.private_ip_address
}

output "public_ip" {
  description = "The public IP address of the admin server (if enabled)"
  value       = var.public_ip_enabled ? azurerm_public_ip.admin[0].ip_address : "NOT_ENABLED"
}

output "ssh_command" {
  description = "CLI command to connect to the admin server"
  value = var.public_ip_enabled ? join("\n", [
    "terraform output -raw ssh_private_key > admin-key.pem && chmod 600 admin-key.pem",
    "ssh -i admin-key.pem ${var.admin_username}@${azurerm_public_ip.admin[0].ip_address}",
    ]) : join("\n", [
    "# No public IP — use Azure Serial Console:",
    "# Azure Portal → Virtual Machines → ${azurerm_linux_virtual_machine.admin.name} → Help → Serial Console",
  ])
}

output "ssh_private_key" {
  description = "The SSH private key for the admin server (sensitive)"
  value       = tls_private_key.admin.private_key_pem
  sensitive   = true
}
