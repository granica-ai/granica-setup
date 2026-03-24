################################################################################
# Resource Group
################################################################################

resource "azurerm_resource_group" "main" {
  name     = "granica-${var.server_name}-rg"
  location = var.region
  tags     = local.default_tags
}

################################################################################
# Virtual Network & Subnets
################################################################################

check "existing_vnet_subnets" {
  assert {
    condition     = length(var.existing_vnet_id) == 0 || length(var.existing_subnet_id) > 0
    error_message = "When existing_vnet_id is set, existing_subnet_id must be provided."
  }
}

locals {
  use_existing_vnet = length(var.existing_vnet_id) > 0
  vnet_id           = local.use_existing_vnet ? var.existing_vnet_id : azurerm_virtual_network.main[0].id
  admin_subnet_id   = local.use_existing_vnet ? var.existing_subnet_id : azurerm_subnet.admin[0].id
}

resource "azurerm_virtual_network" "main" {
  count = local.use_existing_vnet ? 0 : 1

  name                = "granica-vnet-${var.server_name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vpc_cidr]
  tags                = local.default_tags
}

# Admin server subnet
resource "azurerm_subnet" "admin" {
  count = local.use_existing_vnet ? 0 : 1

  name                 = "granica-admin-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 8, 0)] # 10.47.0.0/24
}

# AKS system/on-demand node subnet (used later by granica deploy)
resource "azurerm_subnet" "aks_system" {
  count = local.use_existing_vnet ? 0 : 1

  name                 = "granica-aks-system-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 6, 1)] # 10.47.4.0/22
}

# AKS workload/spot node subnet (used later by granica deploy)
resource "azurerm_subnet" "aks_workload" {
  count = local.use_existing_vnet ? 0 : 1

  name                 = "granica-aks-workload-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 5, 1)] # 10.47.8.0/21
}

# Private endpoints subnet (DB, Storage, Service Bus)
resource "azurerm_subnet" "private_endpoints" {
  count = local.use_existing_vnet ? 0 : 1

  name                 = "granica-private-endpoints-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 8, 16)] # 10.47.16.0/24
}

# Bastion subnet (must be named AzureBastionSubnet)
resource "azurerm_subnet" "bastion" {
  count = var.bastion_enabled && !local.use_existing_vnet ? 1 : 0

  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main[0].name
  address_prefixes     = [cidrsubnet(var.vpc_cidr, 8, 17)] # 10.47.17.0/24
}

################################################################################
# NAT Gateway (provides outbound internet for private subnets)
################################################################################

resource "azurerm_public_ip" "nat" {
  count = local.use_existing_vnet ? 0 : 1

  name                = "granica-nat-ip-${var.server_name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags
}

resource "azurerm_nat_gateway" "main" {
  count = local.use_existing_vnet ? 0 : 1

  name                = "granica-nat-${var.server_name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard"
  tags                = local.default_tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  count = local.use_existing_vnet ? 0 : 1

  nat_gateway_id       = azurerm_nat_gateway.main[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

# Associate NAT gateway with all private subnets
resource "azurerm_subnet_nat_gateway_association" "admin" {
  count = local.use_existing_vnet ? 0 : 1

  subnet_id      = azurerm_subnet.admin[0].id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
}

resource "azurerm_subnet_nat_gateway_association" "aks_system" {
  count = local.use_existing_vnet ? 0 : 1

  subnet_id      = azurerm_subnet.aks_system[0].id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
}

resource "azurerm_subnet_nat_gateway_association" "aks_workload" {
  count = local.use_existing_vnet ? 0 : 1

  subnet_id      = azurerm_subnet.aks_workload[0].id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
}

################################################################################
# Network Security Group
################################################################################

resource "azurerm_network_security_group" "admin" {
  name                = "granica-admin-nsg-${var.server_name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.default_tags

  # Allow SSH from Azure Bastion subnet (if bastion enabled)
  dynamic "security_rule" {
    for_each = var.bastion_enabled ? [1] : []
    content {
      name                       = "AllowBastionSSH"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = cidrsubnet(var.vpc_cidr, 8, 17) # Bastion subnet
      destination_address_prefix = "*"
    }
  }

  # Allow SSH from anywhere (only if public IP enabled — dev/test only)
  dynamic "security_rule" {
    for_each = var.public_ip_enabled ? [1] : []
    content {
      name                       = "AllowPublicSSH"
      priority                   = 110
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }

  # Allow all outbound
  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "admin" {
  count = local.use_existing_vnet ? 0 : 1

  subnet_id                 = azurerm_subnet.admin[0].id
  network_security_group_id = azurerm_network_security_group.admin.id
}

################################################################################
# Azure Bastion (optional — secure SSH access without public IP)
################################################################################

resource "azurerm_public_ip" "bastion" {
  count = var.bastion_enabled ? 1 : 0

  name                = "granica-bastion-ip-${var.server_name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags
}

resource "azurerm_bastion_host" "main" {
  count = var.bastion_enabled ? 1 : 0

  name                = "granica-bastion-${var.server_name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  tunneling_enabled   = true # Required for native SSH client support (az network bastion ssh)
  tags                = local.default_tags

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}
