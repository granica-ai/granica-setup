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
  value       = local.aks_system_subnet_id
}

output "aks_workload_subnet_id" {
  description = "The ID of the AKS workload/spot node subnet"
  value       = local.aks_workload_subnet_id
}

output "private_endpoints_subnet_id" {
  description = "The ID of the private endpoints subnet"
  value       = local.private_endpoints_subnet_id
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
  # Prefer a direct key SSH when a public IP was opted into; otherwise the
  # default path is the Bastion tunnel (aws SSM / gcp IAP analog); Serial
  # Console is only the last resort when neither is present (e.g. existing-VNet
  # mode with no caller-provided access).
  value = var.public_ip_enabled ? join("\n", [
    "terraform output -raw ssh_private_key > admin-key.pem && chmod 600 admin-key.pem",
    "ssh -i admin-key.pem ${var.admin_username}@${azurerm_public_ip.admin[0].ip_address}",
    ]) : (var.bastion_enabled && !local.use_existing_vnet ? join(" ", [
      "az network bastion ssh",
      "--resource-group ${azurerm_resource_group.main.name}",
      "--name granica-bastion-${var.server_name}",
      "--target-resource-id ${azurerm_linux_virtual_machine.admin.id}",
      "--auth-type AAD",
      ]) : join("\n", [
      "# No public IP or Bastion — use Azure Serial Console:",
      "# Azure Portal → Virtual Machines → ${azurerm_linux_virtual_machine.admin.name} → Help → Serial Console",
  ]))
}

output "ssh_private_key" {
  description = "The SSH private key for the admin server (sensitive)"
  value       = tls_private_key.admin.private_key_pem
  sensitive   = true
}
