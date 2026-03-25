## Granica Admin Server Setup (Azure)

This guide will help you set up and destroy a Granica Admin Server with its VNet and subnets.

### Prerequisites

* **Azure subscription** with **Owner** role (or **Contributor** + **User Access Administrator**). Owner is needed because this setup creates a Managed Identity for the admin server and assigns it RBAC roles — the same reason AWS setup needs `iam:CreateRole`/`iam:PassRole` and GCP setup needs `resourcemanager.projectIamAdmin`. This is a one-time bootstrap requirement; after the admin server is created, `granica deploy` runs on the VM using the VM's managed identity.
* Git installed on your system (or use Azure Cloud Shell, which includes Git, Azure CLI, Terraform, kubectl, and Helm).

### Azure Cloud Shell

Azure Cloud Shell is the easiest way to run this setup. It comes pre-installed with `az`, `terraform`, `git`, `kubectl`, and `helm`, and gives you **20 GiB** of persistent home storage.

**To open Azure Cloud Shell:**
1. Go to https://portal.azure.com
2. Click the **Cloud Shell** icon (`>_`) in the top navigation bar
3. Choose **Bash** when prompted
4. If this is your first time, it will create a storage account for Cloud Shell — accept the defaults

Cloud Shell automatically authenticates with your Azure account — no `az login` needed.

**From your laptop (alternative):** install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) and [Terraform](https://developer.hashicorp.com/terraform/install), then run `az login --tenant <your-tenant-id>` before proceeding.

### Quick Start

**1. Register Azure Resource Providers (one-time per subscription)**

Azure requires resource providers to be registered before you can create resources of that type. This is equivalent to enabling GCP APIs (`gcloud services enable ...`).

```bash
# If running from your laptop (not needed in Cloud Shell if already logged in):
# az login --tenant <your-tenant-id>
# az account set --subscription <your-subscription-id>

az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.ManagedIdentity
az provider register --namespace Microsoft.Authorization
az provider register --namespace Microsoft.Resources
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.DBforPostgreSQL
az provider register --namespace Microsoft.ServiceBus
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.OperationalInsights
```

You can verify registration status with:
```bash
az provider show --namespace Microsoft.Compute --query "registrationState" -o tsv
# Should output: Registered
```

**2. Clone Granica Setup Repo**

**Cloud Shell / laptop with Terraform pre-installed:**
```bash
git clone https://github.com/granica-ai/granica-setup.git
cd granica-setup/azure
```

**Laptop without Terraform:** install via tfenv first:
```bash
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
mkdir -p ~/bin
ln -s ~/.tfenv/bin/* ~/bin/
export PATH="$HOME/.tfenv/bin:$PATH"
tfenv install 1.13.4
tfenv use 1.13.4
terraform --version
git clone https://github.com/granica-ai/granica-setup.git
cd granica-setup/azure
```

**3. Create Terraform State Storage (one-time)**

Create an Azure Storage Account to store Terraform state. This is equivalent to creating an S3 bucket (AWS) or GCS bucket (GCP) for state.

```bash
STATE_RG="granica-tfstate-rg"
STATE_ACCOUNT="granicastatestore"   # Must be globally unique, lowercase, no dashes
STATE_REGION="eastus2"              # Region for the state storage (can differ from deployment region)

az group create --name $STATE_RG --location $STATE_REGION
az storage account create \
  --name $STATE_ACCOUNT \
  --resource-group $STATE_RG \
  --location $STATE_REGION \
  --sku Standard_LRS \
  --encryption-services blob
az storage container create --name tfstate --account-name $STATE_ACCOUNT
```

**4. Configure Deployment**

Create `backend.conf` in this directory. A sample is provided in `backend.conf.sample`:
```hcl
resource_group_name  = "granica-tfstate-rg"
storage_account_name = "granicastatestore"
container_name       = "tfstate"
key                  = "your-unique-key/terraform.tfstate"   # Change to a unique identifier for your deployment
```

**Note:** The `key` identifies your deployment. You can reuse the same key to continue a previous deployment. If you use a previous key and want to start fresh, make sure the cleanup steps below have been completed.

Create `terraform.tfvars` in this directory. A sample is provided in `terraform.tfvars.sample`:
```hcl
subscription_id   = "your-subscription-id"    # az account show --query id -o tsv
region            = "eastus2"                 # Region where admin server and Granica will be deployed
package_url       = "https://granica.ai/granica.rpm"
server_name       = "my-server"               # Optional: suffix for admin server name (defaults to "dev")
public_ip_enabled = true                      # Dev/test: direct SSH. Set false for production.
```

**Connect to the admin instance:** By default the VM has no public IP. Set **`public_ip_enabled = true`** to assign a public IP for direct SSH access (dev/test). For production, use **Azure Serial Console** (Portal → VM → Help → Serial Console) which works without a public IP, similar to AWS Session Manager and GCP IAP tunneling.

**Existing VNet (optional):** Set `existing_vnet_id` and `existing_subnet_id` to deploy into an existing VNet instead of creating a new one:
```hcl
existing_vnet_id   = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/my-vnet"
existing_subnet_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/my-subnet"
```

**5. Deploy**
```bash
terraform init -backend-config=backend.conf
terraform apply
```

Your admin server will be created with the name `granica-admin-server-{server_name}`.

**6. Connect to the Admin Server**

   Use AAD SSH login (no keys or passwords needed — equivalent to AWS SSM / GCP IAP):
   ```bash
   az ssh vm --resource-group granica-{server_name}-rg --name granica-admin-server-{server_name}

   # You'll login as your Azure AD identity. Switch to the granica user:
   sudo su - granica
   ```

**7. Granica Setup**

After connecting to the admin server:
```bash
# Check if the startup script has finished (takes around 10-15 mins)
tail -f /var/log/granica-startup.log
# Wait until you see "Granica admin server setup complete"

# Verify config was written
cat config.tfvars    # Should show VNet/subnet IDs, managed identity, etc.

# Verify the installation
granica --help

# Deploy Granica infrastructure + software
granica deploy --var-file config.tfvars
# Will take around 10-15 mins for the clusters to be deployed
```

**Troubleshooting:** If the startup script appears stuck on "Waiting for network...", the ICMP ping check may be blocked by Azure. Kill it and verify network manually:
```bash
sudo pkill -f "ping -c 1"                          # Kill stuck check
curl -s --connect-timeout 3 https://azure.microsoft.com > /dev/null && echo "Network OK"
# If network is OK, re-run the startup script:
sudo bash /var/lib/cloud/instance/scripts/part-001
```

### What Gets Created

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `granica-{server_name}-rg` | Contains all resources |
| VNet | `granica-vnet-{server_name}` | Network with 4 subnets |
| NAT Gateway | `granica-nat-{server_name}` | Outbound internet for private subnets |
| NSG | `granica-admin-nsg-{server_name}` | Firewall rules for admin server |
| Managed Identity | `granica-admin-{server_name}-mi` | VM identity for Azure API access |
| VM | `granica-admin-server-{server_name}` | Admin server (Ubuntu 24.04 LTS) |

**Subnets created** (when not using existing VNet):

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `granica-admin-subnet` | 10.47.0.0/24 | Admin server |
| `granica-aks-system-subnet` | 10.47.4.0/22 | AKS system + on-demand nodes |
| `granica-aks-workload-subnet` | 10.47.8.0/21 | AKS spot/workload nodes |
| `granica-private-endpoints-subnet` | 10.47.16.0/24 | DB, Storage, Service Bus private endpoints |

### Cleanup

To destroy a deployment, clean up Granica / the admin server in reverse order.

**1. Granica Tear Down**
- Connect to the admin server
- Run `granica teardown`

**2. Admin Server Destroy**

From Azure Cloud Shell or your laptop:
```bash
cd granica-setup/azure
terraform init -backend-config=backend.conf
terraform destroy
```

**3. (Optional) State Storage Cleanup**
```bash
az group delete --name granica-tfstate-rg --yes
```