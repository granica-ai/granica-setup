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
tfenv install 1.13.4
tfenv use 1.13.4
terraform --version
git clone https://github.com/granica-ai/granica-setup.git
cd granica-setup/aws
```

**2. Configure Deployment**

Create `terraform.tfvars` in this directory. A sample is provided in `terraform.tfvars.sample` as well as below:
```hcl
aws_region  = "your-region"              # Region where admin server and Granica will be deployed. E.g. us-east-1.
package_url = "https://granica.ai/granica.rpm"
server_name = "my-server"                # Optional: suffix for admin server name (defaults to "dev")
```

**Existing VPC (optional):** To deploy the admin server into an existing VPC instead of creating a new one, set:
```hcl
use_existing_vpc          = true
existing_vpc_id           = "vpc-xxxxxxxxx"
existing_private_subnet_ids = ["subnet-aaa", "subnet-bbb"]
existing_public_subnet_ids  = ["subnet-ccc"]   # Required only if public_ip_enabled = true
```
The admin server is placed in the first private (or public, if `public_ip_enabled`) subnet. By default, an S3 Gateway VPC endpoint is *not* created when using an existing VPC (to avoid `RouteAlreadyExists` if the VPC already has one). Set `create_s3_vpc_endpoint = true` to create it anyway.

**Avoiding EIC quota / existing S3 endpoint:** If you hit "maximum number of Instance Connect Endpoints" or "RouteAlreadyExists" for the S3 endpoint, set:
```hcl
create_instance_connect_endpoint = false
existing_eice_security_group_id  = "sg-xxxxxxxxx"   # SG of your existing EIC (or SSM)
# and/or
create_s3_vpc_endpoint = false   # if the VPC already has an S3 Gateway endpoint
```

Create `backend.conf` in this directory, making sure to set the key to a name unique to the admin server and tfstate. A sample is provided in `backend.conf.sample` and below:
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
