# FDE AWS User Setup

This directory contains the Terraform configuration for setting up FDE users and their permissions in AWS. 
There are 2 types of users that can be created:

- Administer Users: These users have permissions that are required to deploy, upgrade, and manage a Granica deployment
- Operations Users: These users have permissions that are required to perform operations on an already deployed Granica deployment

### Quick Start

Run the following commands from a terminal that is configured with your AWS credentials. See [Authentication and access credentials for the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-authentication.html) for details. For ease of use we recommend using [AWS CloudShell](https://aws.amazon.com/cloudshell/).

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
administer_user_names = ["user@gmail.com"]      # List of FDE administer users to create
operations_user_names = ["user@gmail.com"]      # List of FDE operations users to create
aws_region = "<region>"                         # Region where users will be created
```

Create `backend.conf` in this directory. A sample is provided in `backend.conf.sample` as well as below:
```hcl
bucket = "<terraform-state-bucket-name>"     # Name of the AWS bucket that will store the terraform state
region = "<region>"                          # Region for the AWS bucket that contains the terraform state
key    = "unique-key"                        # Unique identifier for FDE users deployment
```

**3. Deploy**
```bash
terraform init -backend-config=backend.conf
terraform apply
```

### Next Steps

After the FDE users are created share the credentials with the FDE users

### Cleanup

To destroy the FDE users and their permissions:
```bash
terraform destroy
```
