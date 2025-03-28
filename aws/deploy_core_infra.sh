#!/bin/bash
set -euo pipefail

# This script deploys the Granica Admin Server.
# It is designed to be safe to run multiple times (idempotent).

# Check that exactly two arguments are provided
echo "RECOMMEND..Run from AWS Cloud Shell"
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <customer_id> <rpm_url>"
    exit 1
fi

CUSTOMER_ID="$1"
RPM_URL="$2"

# Determine AWS Region from environment variables or an API call
REGION="${AWS_REGION:-$AWS_DEFAULT_REGION}"
if [ -z "$REGION" ]; then
  REGION=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].RegionName' --output text 2>/dev/null || true)
fi
if [ -z "$REGION" ]; then
  echo "ERROR: Unable to determine AWS region."
  exit 1
fi

echo "Using AWS Region: $REGION"
echo "Customer ID: $CUSTOMER_ID"
echo "RPM URL: $RPM_URL"

# Define the remote state bucket name with the random suffix appended
STATE_BUCKET="granica-vpc-tf-${CUSTOMER_ID}-$$"
echo "Using remote state bucket: $STATE_BUCKET"

# Create the remote state bucket if it doesn't exist
if ! aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
    echo "Bucket $STATE_BUCKET does not exist. Creating..."
    if [ "$REGION" == "us-east-1" ]; then
        aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION"
    else
        aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
    fi
else
    echo "Bucket $STATE_BUCKET already exists."
fi

### STEP 1: Install Terraform via tfenv and clone/update Granica Setup Repo

# Install tfenv if not already installed
if [ ! -d "$HOME/.tfenv" ]; then
    echo "Cloning tfenv..."
    git clone https://github.com/tfutils/tfenv.git "$HOME/.tfenv"
else
    echo "tfenv already installed."
fi

# Ensure ~/bin exists and link tfenv binaries
mkdir -p ~/bin
ln -sf "$HOME/.tfenv/bin/"* ~/bin/
export PATH="$HOME/.tfenv/bin:$PATH"

# Install and use Terraform 1.9.3 idempotently
if ! tfenv list | grep -q "1.9.3"; then
    echo "Installing Terraform 1.9.3..."
    tfenv install 1.9.3
fi
tfenv use 1.9.3

echo "Terraform version:"
terraform --version

# Clone or update the Granica setup repository
if [ ! -d "granica-setup" ]; then
    echo "Cloning granica-setup repository..."
    git clone https://github.com/granica-ai/granica-setup.git
else
    echo "granica-setup repository already exists. Updating..."
    cd granica-setup
    git pull
    cd ..
fi

cd granica-setup/aws

### STEP 2: Configure Deployment

# Create or update terraform.tfvars
cat > terraform.tfvars <<EOF
aws_region  = "$REGION"
package_url = "$RPM_URL"
server_name = "$CUSTOMER_ID"
EOF
echo "Updated terraform.tfvars."

# Create or update backend.conf
cat > backend.conf <<EOF
bucket = "$STATE_BUCKET"
region = "$REGION"
key    = "$CUSTOMER_ID"
EOF
echo "Updated backend.conf."

### STEP 3: Deploy

echo "Initializing Terraform with backend configuration..."
terraform init -backend-config=backend.conf

echo "Applying Terraform configuration..."
terraform apply -auto-approve

echo "Deployment complete."
echo "Your Granica Admin Server should now be available as granica-admin-server-$CUSTOMER_ID."
echo "To complete the Granica setup, connect to the instance and run: 'granica deploy --var-file=config.tfvars'"
