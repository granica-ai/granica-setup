# FDE AWS Setup

This directory contains the Terraform configuration for setting up FDE users and their permissions in AWS.

## FDE IAM Users Setup

This guide will help you set up FDE IAM users with required permissions in AWS. This setup should be run from the admin account to create FDE users who will then be able to deploy the admin server in their own accounts.

### Prerequisites

* AWS credentials with administrator access (AWS Cloud Shell)
* Git installed on your system
* Terraform installed (follow main setup guide if needed)

### Quick Start (Dev Mode)

**1. Install Terraform and Clone Setup Repo**
```bash
# Install tfenv for Terraform version management
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
mkdir ~/bin
ln -s ~/.tfenv/bin/* ~/bin/
export PATH="$HOME/.tfenv/bin:$PATH"
tfenv install
tfenv use 1.9.3
terraform --version

# Clone the repository
git clone https://github.com/granica-ai/granica-setup.git
cd granica-setup/customer/fde/aws
```

**2. Configure Deployment**

Create `terraform.tfvars` in this directory. A sample is provided in `terraform.tfvars.sample` as well as below:
```hcl
user_names = ["fde-user1", "fde-user2"]  # List of FDE users to create
aws_region = "us-east-1"                 # Region where users will be created
```

Create `backend.conf` in this directory, making sure to set the key to a name unique to the FDE users and tfstate. A sample is provided in `backend.conf.sample` and below:
```hcl
bucket = "your-terraform-state-bucket"
region = "us-west-2"                    # Region for the AWS bucket that contains the terraform state
key    = "fde/iam-users/terraform.tfstate"  # Unique identifier for FDE users deployment
```

**Note:** The `key` provided identifies your deployment and the state stored in the AWS bucket. You can use the same key to continue with a previously created deployment. If you use a previous key and want to start fresh then make sure that cleanup steps below have been completed.

**3. Deploy**
```bash
terraform init -backend-config=backend.conf
terraform plan    # Review the changes
terraform apply
```

Your FDE users will be created with the following policies attached:
- AWSCloudShellFullAccess
- granica-lb
- project-n-admin-deploy
- project-n-admin-vpc-permissions
- project-n-eks-addons-terraform
- project-n-oidc-additional-terraform

### Next Steps

After the FDE users are created:
1. Share the credentials with the FDE users
2. FDE users can then log into their own AWS accounts
3. FDE users can deploy the admin server using the main setup guide in their respective accounts

### Cleanup

To destroy the FDE users and their permissions:
```bash
terraform destroy
```

**Note:** This should only be done when the FDE users no longer need access to deploy or manage admin servers.

### Note

The setup script creates a workspace in `/aws/mde/terraform-workspaces/fde` to avoid CloudShell storage limitations. The workspace is accessible via the symlink `~/fde-workspace`. This is necessary to prevent "no space left on device" errors during Terraform operations.

