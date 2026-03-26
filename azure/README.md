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
   ```bash
   az ssh vm --resource-group granica-{server_name}-rg --name granica-admin-server-{server_name}

   # server_name is what you provided in the terraform.tfvars file
   ```
   (Use the az ssh command output at the end of the terraform apply to connect to the admin server)
   ```bash
   $ sudo su - granica # Use granica user to run granica commands
   # Check if the granica package has finished installation (takes around 10-15 mins)
   # Can check the logs here: tail -f /var/log/granica-startup.log
   $ granica --help
   $ granica deploy --var-file config.tfvars
   # Will take around 10-15 mins for the clusters to be deployed
   ```
