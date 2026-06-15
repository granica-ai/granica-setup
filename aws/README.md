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

### Setup

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

Create `backend.conf` in this directory so Terraform stores its state in S3. Set `key` to a value unique to this admin server. A sample is provided in `backend.conf.sample` and below:
```hcl
bucket = "your-bucket"                  # S3 bucket that holds the Terraform state
region = "your-state-bucket-region"     # Region where the state bucket lives
key    = "your-unique-key"              # Change this to a unique identifier for your deployment
```

**Note:** The `key` identifies your deployment and the state stored in the AWS bucket. You can reuse the same key to continue with a previously created deployment. If you reuse a previous key and want to start fresh, make sure the cleanup steps below have been completed first.

**2.1 [Optional] Existing VPC**

Set `existing_vpc_id` (and subnets) to deploy into an existing VPC instead of creating a new one:
```hcl
existing_vpc_id             = "vpc-xxxxxxxxx"
existing_private_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
existing_public_subnet_ids   = ["subnet-ccc"]   # Required only if public_ip_enabled = true
```
The admin server is placed in the first private (or public, if `public_ip_enabled`) subnet. By default, an S3 Gateway VPC endpoint is *not* created when `existing_vpc_id` is set (to avoid `RouteAlreadyExists`). Set `create_s3_vpc_endpoint = true` to create it anyway.

**2.2 [Optional] IAM role/policy naming and permission boundary**

If your AWS account enforces an IAM naming convention, an IAM path, or a permissions boundary (e.g. a centrally-governed "customer-managed" model), set the variables below. They control how this module names and scopes the roles/policies it creates. All default to "off", so omit them entirely unless your account requires them:

```hcl
role_path                         = "/OneCloud/"                                          # IAM path for all roles created (must start and end with "/")
role_name_prefix                  = "CustomerManagedBasic-"                               # Prefix prepended to every role name
policy_name_prefix                = "CustomerManaged_"                                    # Prefix prepended to every policy name
policy_path                       = "/"                                                   # IAM path for all policies (must start and end with "/")
permission_boundary_arn           = "arn:aws:iam::<ACCOUNT_ID>:policy/BasicRole_Boundary" # Permissions boundary attached to roles created by this module
permission_boundary_on_admin_role = false                                                 # Also attach the boundary to the admin/deployer role?
```

**3. Deploy the admin server**
```bash
terraform init -backend-config=backend.conf
terraform apply
```

This creates the admin server (named `granica-admin-server-{server_name}`) along with its VPC/subnets. Granica itself is **not** deployed yet — that runs from the admin server in the next step.

**4. Run Granica Setup from the admin server**

Once `terraform apply` finishes, connect to the admin server and deploy Granica from it:

- **Connect** to the `granica-admin-server-{server_name}` instance — EC2 console **Connect → Session Manager**, or the `aws ssm start-session` command from `terraform output admin_server_ec2_instance_connect_endpoint_connect_command`.
- **Switch to `ec2-user`.** A Session Manager session starts as Linux user **`ssm-user`**, but `config.tfvars` and the Granica files under `/home/ec2-user` are owned by **`ec2-user`**, so switch accounts first:

  ```bash
  whoami                    # ssm-user
  sudo su - ec2-user
  whoami                    # ec2-user
  ```

- **Deploy Granica:**

  ```bash
  granica deploy --var-file=config.tfvars
  ```

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
