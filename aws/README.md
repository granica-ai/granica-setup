## Granica Admin Server Setup

This guide will help you set up and destroy a Granica Admin Server with its VPC and subnets.

### Prerequisites

* **AWS credentials** sufficient to run Terraform for this module. You do **not** need account administrator access if you follow a minimal FDE policy set.
  * **Existing VPC (typical):** customer-managed policy from [`customer/fde/aws/docs/fde-user-existing-vpc.json`](../customer/fde/aws/docs/fde-user-existing-vpc.json) plus optional AWS managed policies for CloudShell / console read. Terraform creates the admin EC2 and `project-n-admin-*` instance profile; **`granica deploy` and EKS** run **on that instance** using its role, not your console user’s deploy permissions.
  * **New VPC:** EC2/VPC permissions for `terraform-aws-modules/vpc` plus the admin instance; see [`customer/fde/aws/docs/fde-user-new-vpc.json`](../customer/fde/aws/docs/fde-user-new-vpc.json). Replace **`ACCOUNT_ID`**. VPC build APIs use `Resource: *` (except **`RunInstances`** / **`TerminateInstances`**, which are scoped + tag conditions for the admin server).
* Git installed on your system (or use AWS CloudShell, which includes Git).

### AWS CloudShell and Terraform disk space

AWS CloudShell gives you a small **home** volume (on the order of **1 GiB**). A normal `terraform init` in `granica-setup/aws` stores the AWS provider (and module/plugin metadata) under `.terraform` in that directory, which often **fills `$HOME`** and breaks installs, shells, or git.

**Before the first `terraform init` in this directory**, point Terraform’s working data and plugin cache at **`/tmp`**, which typically has more room in CloudShell (treat it as **ephemeral**: new CloudShell sessions need these exports again):

```bash
mkdir -p /tmp/granica-setup-aws-tf-data /tmp/terraform-plugin-cache
export TF_DATA_DIR=/tmp/granica-setup-aws-tf-data
export TF_PLUGIN_CACHE_DIR=/tmp/terraform-plugin-cache
```

Use the **same** `export` lines in any later session before `terraform init`, `terraform apply`, or `terraform destroy` (remote state stays in S3; this only affects local provider/module cache).

If you already ran `init` without this and hit “no space left”, remove the old local cache under `granica-setup/aws/.terraform` and default plugin dirs under `$HOME/.terraform.d` if present, then set the variables above and run `terraform init` again.

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

**AWS CloudShell:** run the `mkdir` / `export` block from **[AWS CloudShell and Terraform disk space](#aws-cloudshell-and-terraform-disk-space)** here, before `terraform init`.

**2. Configure Deployment**

Create `terraform.tfvars` in this directory. A sample is provided in `terraform.tfvars.sample` as well as below:
```hcl
aws_region  = "your-region"              # Region where admin server and Granica will be deployed. E.g. us-east-1.
package_url = "https://granica.ai/granica.rpm"
server_name = "my-server"                # Optional: suffix for admin server name (defaults to "dev")
airflow_enabled = true                   # Optional: enables EFS permissions for Airflow deployment (defaults to false)
```

**Existing VPC (optional):** Set `existing_vpc_id` (and subnets) to deploy into an existing VPC instead of creating a new one:
```hcl
existing_vpc_id             = "vpc-xxxxxxxxx"
existing_private_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
existing_public_subnet_ids   = ["subnet-ccc"]   # Required only if public_ip_enabled = true
```
The admin server is placed in the first private (or public, if `public_ip_enabled`) subnet. By default, an S3 Gateway VPC endpoint is *not* created when `existing_vpc_id` is set (to avoid `RouteAlreadyExists`). Set `create_s3_vpc_endpoint = true` to create it anyway.

**Connect to the admin instance:** Variable **`instance_connect`** (default **empty**): use **Session Manager** (the instance profile includes `AmazonSSMManagedInstanceCore`) or your own path. Set to **`"create"`** to create an EC2 Instance Connect Endpoint and its security group, or to a security group id (**`sg-...`**) to allow ingress from an existing endpoint or bastion without creating resources.

**Avoiding S3 `RouteAlreadyExists`:** If the VPC already has an S3 gateway endpoint, set `create_s3_vpc_endpoint = false`.
```hcl
instance_connect         = "create"              # or "sg-xxxxxxxxx", or omit for Session Manager only
create_s3_vpc_endpoint   = false
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
# CloudShell: export TF_DATA_DIR / TF_PLUGIN_CACHE_DIR as in Quick Start
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
# CloudShell: same TF_DATA_DIR / TF_PLUGIN_CACHE_DIR exports as for init, then:
terraform init -backend-config=backend.conf
terraform destroy
```
