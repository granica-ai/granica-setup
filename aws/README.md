## Granica Admin Server Setup

This guide will help you set up a Granica Admin Server with its VPC and subnets.

### Prerequisites

* AWS credentials with administrator access (either via AWS Cloud Shell or your local machine)
* Git installed on your system

### Quick Start (Dev Mode)

**1. Install Terraform and Clone Granica Setup Repo**
```bash
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
mkdir ~/bin
ln -s ~/.tfenv/bin/* ~/bin/
tfenv install
tfenv use 1.9.3
terraform --version
git clone https://github.com/granica-ai/granica-setup.git
cd granica-setup/aws
```

**2. Configure Deployment**

Edit `terraform.tfvars`:
```hcl
aws_region  = "your-region"              # Region where admin server will be deployed
package_url = "https://granica.ai/granica.rpm"
server_name = "my-server"                # Optional: suffix for admin server name (defaults to "dev")
```

**3. Deploy**
```bash
terraform init
terraform apply
```

Your admin server will be created with the name `granica-admin-server-{server_name}`.
### Production Setup (Optional)

For production deployments, it is essential to preserve the Terraform state (tfstate) for the admin server itself. This is achieved by creating a custom backend configuration file, `backend.conf`, which specifies the S3 bucket to store the Terraform state.

**1. Create backend.conf**
```hcl
bucket = "your-terraform-state-bucket"    # S3 bucket to store Terraform state
region = "your-state-bucket-region"       # Region where the S3 bucket is located
key    = "your-cluster-key"              # Unique identifier for this deployment
```

**2. Deploy with Custom State Configuration**
```bash
terraform init -backend-config=backend.conf
terraform apply
```

By using this custom backend configuration, your admin server will be created with the name `granica-admin-server-{key}`, where `key` is the value specified in `backend.conf`. This approach ensures that the Terraform state is safely stored in the specified S3 bucket, allowing for easier management and versioning of your infrastructure deployments.
