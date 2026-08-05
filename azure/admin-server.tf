################################################################################
# Admin Server VM
################################################################################
# Azure Linux VM that runs `granica deploy` to create the AKS cluster and
# all supporting infrastructure. Equivalent to:
#   AWS: aws_instance (Amazon Linux 2023, t2.small)
#   GCP: google_compute_instance (CentOS 9, e2-small)
################################################################################

# Public IP for admin server (only if public_ip_enabled — dev/test)
resource "azurerm_public_ip" "admin" {
  count = var.public_ip_enabled ? 1 : 0

  name                = "granica-admin-ip-${var.server_name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.default_tags
}

# NIC for admin server
resource "azurerm_network_interface" "admin" {
  name                = "granica-admin-nic-${var.server_name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.default_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.admin_subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip_enabled ? azurerm_public_ip.admin[0].id : null
  }
}

# SSH key for VM access
resource "tls_private_key" "admin" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_linux_virtual_machine" "admin" {
  name                = "granica-admin-server-${var.server_name}"
  location            = var.region
  resource_group_name = azurerm_resource_group.main.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = local.default_tags

  network_interface_ids = [azurerm_network_interface.admin.id]

  # Managed identity for Azure API access (equivalent to IAM instance profile / GCP SA)
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.admin.id]
  }

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.admin.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  # Azure Linux 2 (RHEL-based, similar to Amazon Linux 2023)
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
#!/bin/bash

exec > >(tee /var/log/granica-startup.log)
exec 2>&1

echo "=== Granica admin server setup started ==="

# Wait for network (use curl instead of ping — Azure NSGs may block ICMP)
echo "Checking network connectivity..."
until curl -s --connect-timeout 3 https://azure.microsoft.com > /dev/null 2>&1; do
  echo "Waiting for network..."
  sleep 2
done
echo "Network is reachable"

# Wait for apt lock to be released (cloud-init may be running)
while fuser /var/lib/dpkg/lock-frontend &>/dev/null 2>&1; do
  echo "Waiting for apt lock..."
  sleep 5
done

# Install dependencies
echo "Installing dependencies..."
apt-get update -y
apt-get install -y \
  jq git curl wget unzip tar make gcc \
  python3 python3-pip python3-venv \
  openssl libssl-dev libffi-dev \
  libsqlite3-dev zlib1g-dev \
  ca-certificates gnupg lsb-release \
  cron

# Install Azure CLI
echo "Installing Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Terraform
echo "Installing Terraform..."
wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update -y && apt-get install -y terraform

# Install kubectl
echo "Installing kubectl..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -y && apt-get install -y kubectl

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Create granica user home directory and setup
echo "Setting up ${var.admin_username} user..."
mkdir -p /home/${var.admin_username}

# Write config.tfvars with infrastructure IDs (used by granica deploy)
echo "Writing config.tfvars..."
cat > /home/${var.admin_username}/config.tfvars <<'TFVARS'
subscription_id    = "${var.subscription_id}"
region             = "${var.region}"
resource_group     = "${azurerm_resource_group.main.name}"
vnet_id            = "${local.vnet_id}"
admin_subnet_id    = "${local.admin_subnet_id}"
%{if !local.use_existing_vnet~}
aks_system_subnet_id    = "${azurerm_subnet.aks_system[0].id}"
aks_workload_subnet_id  = "${azurerm_subnet.aks_workload[0].id}"
private_endpoints_subnet_id = "${azurerm_subnet.private_endpoints[0].id}"
%{endif~}
admin_identity_id       = "${azurerm_user_assigned_identity.admin.id}"
admin_identity_client_id = "${azurerm_user_assigned_identity.admin.client_id}"
admin_server_name       = "granica-admin-server-${var.server_name}"
owner_id                = "${data.azurerm_client_config.current.object_id}"
TFVARS

chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/config.tfvars

# Setup project-n config directory
mkdir -p /home/${var.admin_username}/.project-n/azure/default/infrastructure
echo '{"default_platform":"azure"}' > /home/${var.admin_username}/.project-n/config
chmod -R 755 /home/${var.admin_username}/.project-n
chown -R ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/.project-n

# Auto-login with managed identity on every session (equivalent to AWS instance profile / GCP SA auto-auth)
echo "Configuring Azure CLI auto-login with managed identity..."
cat >> /home/${var.admin_username}/.bashrc << 'BASHRC'
# Auto-login with VM's managed identity (like AWS instance profile / GCP service account)
if ! az account show &>/dev/null 2>&1; then
  az login --identity --client-id ${azurerm_user_assigned_identity.admin.client_id} &>/dev/null
  az account set --subscription ${var.subscription_id} &>/dev/null
fi
BASHRC
chown ${var.admin_username}:${var.admin_username} /home/${var.admin_username}/.bashrc

# Also login now for the current setup session
su ${var.admin_username} -c 'az login --identity --client-id ${azurerm_user_assigned_identity.admin.client_id} 2>/dev/null || echo "MI login will work after VM is fully provisioned"'
su ${var.admin_username} -c 'az account set --subscription ${var.subscription_id}'

# Install Granica RPM
max_attempts=5
attempt_num=1
success=false
while [ $success = false ] && [ $attempt_num -le $max_attempts ]; do
  echo "Attempting Granica package install (attempt $attempt_num/$max_attempts)..."
  wget --directory-prefix=/tmp ${var.package_url}
  rpm_file=$(basename ${var.package_url})
  # Convert RPM to deb for Ubuntu (using alien), or install directly if deb
  if [[ "$rpm_file" == *.rpm ]]; then
    apt-get install -y alien
    alien -d "/tmp/$rpm_file" && dpkg -i /tmp/*.deb
  elif [[ "$rpm_file" == *.deb ]]; then
    dpkg -i "/tmp/$rpm_file"
  fi
  if [ $? -eq 0 ]; then
    echo "Granica package install succeeded"
    success=true
  else
    echo "Attempt $attempt_num failed. Retrying in 5 seconds..."
    sleep 5
    ((attempt_num++))
  fi
done

if [ "$success" = false ]; then
  echo "ERROR: Failed to install Granica package after $max_attempts attempts"
fi

# Ensure cron is enabled
systemctl enable cron
systemctl start cron

echo "=== Granica admin server setup complete ==="
EOF
  )

  depends_on = [
    azurerm_nat_gateway_public_ip_association.main,
    azurerm_subnet_nat_gateway_association.admin,
    azurerm_subnet_network_security_group_association.admin,
  ]
}

################################################################################
# AAD SSH Login Extension
################################################################################
# Enables Azure AD-based SSH login — no SSH keys or passwords needed.
# Equivalent to: AWS SSM Session Manager, GCP IAP tunneling
# Usage: az ssh vm --resource-group <rg> --name <vm>
################################################################################

resource "azurerm_virtual_machine_extension" "aad_ssh" {
  name                 = "AADSSHLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.admin.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"
}

# Grant the deployer VM Administrator Login so they can SSH via AAD
resource "azurerm_role_assignment" "vm_admin_login" {
  scope                = azurerm_linux_virtual_machine.admin.id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = data.azurerm_client_config.current.object_id
}
