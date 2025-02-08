# FDE AWS Setup

This directory contains the Terraform configuration for setting up FDE users and their permissions in AWS.

## Prerequisites

* AWS credentials with administrator access (AWS Cloud Shell)
* Git installed on your system

## Quick Start

1. **Setup Workspace**
```bash
# Make the setup script executable
chmod +x setup_workspace.sh

# Run the setup script
./setup_workspace.sh
```

2. **Change Directory**
```bash
cd ~/fde-workspace
```

3. **Configure Deployment**

Create `terraform.tfvars` in this directory. A sample is provided in `terraform.tfvars.sample` as well as below:
```hcl
aws_region  = "your-region"              # Region where admin server and Granica will be deployed. E.g. us-east-1.
package_url = "https://granica.ai/granica.rpm"
server_name = "my-server"                # Optional: suffix for admin server name (defaults to "dev")
```

Create `backend.conf` in this directory, making sure to set the key to a name unique to the admin server and tfstate. A sample is provided in `backend.conf.sample` and below:
```hcl
bucket = "kry-ci-granica-setup-terraform-state"
region = "us-west-2"                    # Don't change. This is the region for the AWS bucket that contains the terraform state.
key    = "your-unique-key"              # Change this to a unique identifier for your deployment
```

**Note:** The `key` provided identifies your deployment and the state stored in the AWS bucket. You can use the same key to continue with a previously created deployment. If you use a previous key and want to start fresh then make sure that cleanup steps below have been completed.

4. **Deploy**
```bash
terraform init -backend-config=backend.conf
terraform plan
terraform apply
```

5. **Cleanup**

To destroy the deployment:
```bash
cd ~/fde-workspace
terraform destroy
```

## Note

This setup script creates a workspace in `/aws/mde/terraform-workspaces/fde` to avoid CloudShell storage limitations. The workspace is accessible via the symlink `~/fde-workspace`. 
