## Granica Admin Server Setup

This guide will help you set up and destroy a Granica Admin Server with its VPC and subnets.

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

Edit `terraform.tfvars`:
```hcl
aws_region  = "your-region"              # Region where admin server and Granica will be deployed. E.g. us-east-1.
package_url = "https://granica.ai/granica.rpm"
server_name = "my-server"                # Optional: suffix for admin server name (defaults to "dev")
```

Edit `backend.conf` and change the key to a unique name to the admin server and tfstate:
```hcl
bucket = "kry-ci-granica-setup-terraform-state"
region = "us-west-2"                    # Don't change. This is the region for the AWS bucket that contains the terraform state.
key    = "your-unique-key"              # Change this to a unique identifier for your deployment
```

**Note:** The `key` provided identifies your deployment and the state stored in the AWS bucket. You can use the same key to continue with a previously created deployment. If you use a previous key and want to start fresh then make sure that cleanup steps below have been completed.

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
key    = "your-cluster-key"               # Unique identifier for this deployment
```

**2. Deploy with Custom State Configuration**
```bash
terraform init -backend-config=backend.conf
terraform apply
```

By using this custom backend configuration, your admin server will be created with the name `granica-admin-server-{key}`, where `key` is the value specified in `backend.conf`. This approach ensures that the Terraform state is safely stored in the specified S3 bucket, allowing for easier management and versioning of your infrastructure deployments.

### Cleanup

To destroy a deployment cleanup Granica / the admin server in the reverse order of the set up.
**1. Granica Tear Down **

- Go to the AWS EC2 console
- Connect to the `granica-admin-server-{server_name}` instance
- Run the command `granica teardown`

**2. Admin Server Destroy**
From the AWS Cloud Shell:
```bash
terraform destroy
```
