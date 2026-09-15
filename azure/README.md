## Granica Azure Admin Server

### Prerequisites
If you are working in Azure Cloud Shell you must be logged in as Owner. If you are running from your laptop you will need Azure CLI credentials with Owner access on the subscription.
- An Azure subscription with Owner role (needed to create managed identity and assign RBAC roles)

### Instructions

1. Register Azure Resource Providers
   ```bash
   az login --tenant <your-tenant-id>
   az account set --subscription <your-subscription-id>

   az provider register --namespace Microsoft.Compute
   az provider register --namespace Microsoft.Network
   az provider register --namespace Microsoft.Storage
   az provider register --namespace Microsoft.ManagedIdentity
   az provider register --namespace Microsoft.Authorization
   az provider register --namespace Microsoft.Resources
   az provider register --namespace Microsoft.ContainerService
   az provider register --namespace Microsoft.DBforPostgreSQL
   az provider register --namespace Microsoft.ServiceBus
   az provider register --namespace Microsoft.OperationalInsights
   ```

2. Install Terraform on Azure Cloud Shell or on your laptop
   ```bash
   git clone https://github.com/tfutils/tfenv.git ~/.tfenv
   mkdir ~/bin
   ln -s ~/.tfenv/bin/* ~/bin/
   export PATH="$HOME/.tfenv/bin:$PATH"
   tfenv install 1.13.4
   tfenv use 1.13.4
   terraform --version
   git clone https://github.com/granica-ai/granica-setup.git
   cd granica-setup/azure
   ```

3. Create Azure Storage Account that will host admin server terraform state
   ```bash
   az group create --name granica-tfstate-rg --location <region>
   az storage account create --name <account-name> --resource-group granica-tfstate-rg \
     --location <region> --sku Standard_LRS --encryption-services blob
   az storage container create --name tfstate --account-name <account-name>
   ```

4. Provide the following parameters in `backend.conf`
   ```bash
   resource_group_name  = "granica-tfstate-rg"
   storage_account_name = "<account-name>"
   container_name       = "tfstate"
   key                  = "<your-unique-key>/terraform.tfstate"
   ```

5. Provide values for the parameters in the `terraform.tfvars` file
   ```bash
   subscription_id   = "your-subscription-id"    # az account show --query id -o tsv
   region            = "eastus2"
   package_url       = "https://granica.ai/granica.rpm"
   server_name       = "CHANGE_ME"
   ```

6. Run the following
   ```bash
   terraform init -backend-config=backend.conf
   terraform apply
   ```

7. Login to the Admin Server

   By default the admin server has **no public IP** and is reached through
   **Azure Bastion** (the VM stays private). `terraform apply` prints the exact
   command.
   ```bash
   # Default (bastion_enabled = true): tunnel in through Bastion
   az network bastion ssh \
     --resource-group granica-{server_name}-rg \
     --name granica-bastion-{server_name} \
     --target-resource-id $(terraform output -raw instance_id) \
     --auth-type AAD

   # server_name is what you provided in the terraform.tfvars file
   ```
   If you instead set `public_ip_enabled = true` (dev/test) the server gets a
   public IP + an SSH rule, and you can connect directly:
   ```bash
   az ssh vm --resource-group granica-{server_name}-rg --name granica-admin-server-{server_name}
   ```

   **Existing-VNet mode** (`existing_vnet_id` set): no Bastion and no public IP
   are created, so this state does not provision any access path to the admin
   server. You must supply your own connectivity into the VNet — an existing
   Bastion host, a VPN gateway, or VNet peering from a network you can reach —
   and then SSH to the VM's private IP as the `granica` user (AAD login works
   over your own route). The `ssh_command` output reflects this.

   (Use the connect command printed at the end of the terraform apply)
   ```bash
   $ sudo su - granica # Use granica user to run granica commands
   # Check if the granica package has finished installation (takes around 10-15 mins)
   # Can check the logs here: tail -f /var/log/granica-startup.log
   $ granica --help
   $ granica deploy --var-file config.tfvars
   # Will take around 10-15 mins for the clusters to be deployed
   ```

### Teardown

Destroy in the reverse order of creation. The krypton workload consumes this
state's resource group, subnets, NAT gateway associations, admin managed
identity, and access path, so it must go first.

1. On the admin server, destroy the Granica workload:
   ```bash
   $ sudo su - granica
   $ granica destroy --var-file config.tfvars
   ```
2. From your workstation (or Cloud Shell), destroy this bootstrap state:
   ```bash
   terraform destroy -var-file=terraform.tfvars
   ```

Do not `terraform destroy` this state before the workload is gone. Its subnets
are still in use by the AKS nodes and Postgres, and its resource group is not
empty, so the destroy will fail or strand orphaned resources. Tear down the
workload first, then this state.
