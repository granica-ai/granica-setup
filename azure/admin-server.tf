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

  # RHEL 9 (RHEL-family, matching the aws/gcp admin servers) so the Granica RPM
  # installs natively via yum — its %post pulls the prebuilt rhel9 python +
  # terraform + helm + CLI. Avoids the Ubuntu/alien path that broke the CLI
  # bootstrap (RPM %post assumes a RHEL family + numeric scriptlet args).
  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
#!/bin/bash

exec > >(tee /var/log/granica-startup.log)
exec 2>&1

echo "=== Granica admin server setup started ==="

# RHEL 9.8 PAYG images auto-enable the subscription-manager product-id dnf plugin,
# whose post-transaction hook fails ("Installed products updated. Error: Transaction
# failed") on an unregistered system. That makes the AADSSHLoginForLinux VM
# extension's `yum install aadsshlogin-selinux` exit non-zero (terminal extension
# failure) even though the package itself installs cleanly. Disable it as early as
# custom_data runs. NOTE: custom_data races the extension handler; if the extension
# still loses the race and fails, recover with:
#   az vm extension delete -g <rg> --vm-name <vm> -n AADSSHLoginForLinux
#   terraform apply   # retries the ext; package already installed -> "Nothing to do"
subscription-manager config --rhsm.auto_enable_yum_plugins=0 --rhsm.manage_repos=0 2>/dev/null || true
sed -i 's/^enabled=1/enabled=0/' /etc/dnf/plugins/product-id.conf /etc/dnf/plugins/subscription-manager.conf 2>/dev/null || true

# Wait for outbound HTTPS (Azure NSGs may block ICMP). Bounded: in existing-VNet
# mode there may be no NAT/egress at all, so an unbounded wait would hang cloud-init
# forever. Fail loudly after ~2 min so the failure is visible in the startup log.
echo "Checking network connectivity..."
net_ok=0
for i in $(seq 1 40); do
  if curl -s --connect-timeout 3 https://packages.microsoft.com > /dev/null 2>&1; then
    net_ok=1
    break
  fi
  echo "Waiting for network... (attempt $i/40)"
  sleep 3
done
if [ "$net_ok" -ne 1 ]; then
  echo "ERROR: no outbound HTTPS after ~2 min. Check VNet egress (NAT gateway / route / NSG); in existing-VNet mode the VNet must provide outbound internet access." >&2
  exit 1
fi
echo "Network is reachable"

# Base dependencies (RHEL/dnf). terraform, helm, the prebuilt rhel9 python, and
# the projectn CLI are all installed by the Granica RPM %post below (identical to
# the aws/gcp RHEL admin servers), so the only extra we add here is az-cli.
#
# NOTE: deliberately NO `yum -y update` here. A full package update holds the
# yum/rpm lock for minutes at first boot and races the AADSSHLoginForLinux VM
# extension's own `yum makecache` (6 quick retries), causing the extension to
# fail with a terminal error. Install only the specific packages we need.
yum install -y jq git curl wget unzip tar make gcc ca-certificates || true
update-ca-trust 2>/dev/null || true

# Azure CLI (Microsoft RHEL repo)
echo "Installing Azure CLI..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null || true
dnf install -y https://packages.microsoft.com/config/rhel/9/packages-microsoft-prod.rpm 2>/dev/null || true
for i in 1 2 3; do
  dnf install -y azure-cli && command -v az >/dev/null 2>&1 && break
  echo "Azure CLI install attempt $i failed; retrying in 15s..."
  sleep 15
done

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
vnet_name          = "${local.vnet_name}"
admin_subnet_id    = "${local.admin_subnet_id}"
aks_system_subnet_id    = "${local.aks_system_subnet_id}"
aks_workload_subnet_id  = "${local.aks_workload_subnet_id}"
private_endpoints_subnet_id = "${local.private_endpoints_subnet_id}"
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
  # Native install (RHEL): the RPM %post pulls the prebuilt rhel9 python +
  # terraform + helm + the projectn CLI. curl to a local file first (handles
  # signed URLs with query strings that yum's URL fetcher chokes on), then
  # yum-install the local rpm.
  if curl -fsSL "${var.package_url}" -o /tmp/granica.rpm && yum install -y /tmp/granica.rpm; then
    echo "Granica package install succeeded"
    success=true
  else
    echo "Attempt $attempt_num failed. Retrying in 15 seconds..."
    sleep 15
    ((attempt_num++))
  fi
done

if [ "$success" = false ]; then
  echo "ERROR: Failed to install Granica package after $max_attempts attempts"
fi

# Ensure cron is enabled (RHEL uses crond)
systemctl enable crond 2>/dev/null || true
systemctl start crond 2>/dev/null || true

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
