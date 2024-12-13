## Granica Admin Server Setup

This guide will help you set up a Granica Admin Server with its VPC and subnets.

### Prerequisites

* AWS credentials with administrator access (AWS Cloud Shell)
* Git installed on your system

### Quick Start (Dev Mode)

**1. Install Terraform and Clone Granica Setup Repo**
```bash
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
mkdir ~/bin
ln -s ~/.tfenv/bin/* ~/bin/
export PATH="$HOME/.tfenv/bin:$PATH"
tfenv install
tfenv use 1.9.3
terraform --version
git clone https://github.com/granica-ai/granica-setup.git
cd granica-setup/aws
```

**2. Configure Deployment**

Create `terraform.tfvars` in this directory. A sample is provided in `terraform.tfvars.sample` as well as below:
```hcl
aws_region  = "your-region"              # Region where admin server will be deployed
package_url = "https://granica.ai/granica.rpm"
server_name = "my-server"                # Optional: suffix for admin server name (defaults to "dev")
```

Create `backend.conf` in this directory, making sure to set the key to a name unique to the admin server and tfstate. A sample is provided in `backend.conf.sample` and below:
```hcl
bucket = "kry-ci-granica-setup-terraform-state"
region = "us-west-2"
key    = "your-unique-key"              # Change this to a unique identifier for your deployment
```

**3. Deploy**
```bash
terraform init -backend-config=backend.conf
terraform apply
```

Your admin server will be created with the name `granica-admin-server-{server_name}`.

**4. Granica Setup**

After the deployment, you can set up Granica by following these steps:

- Go to the AWS EC2 console
- Connect to the `granica-admin-server-{server_name}` instance
- Run the command `granica deploy --var-file=config.tfvars`

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
