#!/bin/bash
set -euo pipefail

# This script deploys the Granica Admin Server.
# It is designed to be safe to run multiple times (idempotent).

# Check arguments
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <customer_id> <rpm_url> <zone> [deployment_name]"
    echo "  deployment_name  Optional label to distinguish multiple clusters for the same customer"
    echo "                   (e.g. prod, staging). If omitted, a random suffix is generated"
    echo "                   on first run and persisted for subsequent runs."
    exit 1
fi

if [ "$GOOGLE_CLOUD_SHELL" = "true" ]; then
  echo "Running inside a Google Cloud Shell Terminal"
else
  echo "Warning: Not running in a Google Cloud Shell Terminal. This script was designed to run in a Google Cloud Shell Terminal and may not work as expected."
fi

if gcloud auth list --format="value(account)" 2>/dev/null | grep -q .; then
  echo "You are logged in to gcloud as: $(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
else
  echo "You are NOT logged in to gcloud. Please follow the prompts to login."
  gcloud auth login --update-adc
fi

CUSTOMER_ID="$1"
RPM_URL="$2"
ZONE="$3"

# Resolve deployment name: explicit arg > persisted random > generate new random
DEPLOY_ID_FILE="$HOME/.granica-deploy-id-${CUSTOMER_ID}"
if [ -n "${4:-}" ]; then
  DEPLOYMENT_NAME="$4"
elif [ -f "$DEPLOY_ID_FILE" ]; then
  DEPLOYMENT_NAME=$(cat "$DEPLOY_ID_FILE")
  echo "Reusing persisted deployment name from $DEPLOY_ID_FILE"
else
  DEPLOYMENT_NAME=$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')
  echo "$DEPLOYMENT_NAME" > "$DEPLOY_ID_FILE"
  echo "Generated new deployment name '$DEPLOYMENT_NAME' (saved to $DEPLOY_ID_FILE)"
fi
REGION=${ZONE%-*}
PROJECT=$(gcloud config get-value project 2>/dev/null | tail -n 1)

echo "Using GCP Project:              $PROJECT"
echo "Using GCP Region:               $REGION"
echo "Using GCP Zone:                 $ZONE"
echo "Customer ID:                    $CUSTOMER_ID"
echo "Deployment Name:                $DEPLOYMENT_NAME"
echo "RPM URL:                        $RPM_URL"

# State bucket is deterministic: same (customer_id, deployment_name) always resolves to the same bucket.
# This makes re-runs idempotent while supporting multiple clusters per customer.
STATE_BUCKET="granica-vpc-tf-${CUSTOMER_ID}-${DEPLOYMENT_NAME}"
echo "Using remote state bucket:      $STATE_BUCKET"

read -p "Would you like to proceed? (y/n): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  echo "Proceeding..."
else
  echo "Aborted."
  exit 1
fi

echo "Checking for application-default credentails..."
if gcloud auth application-default print-access-token > /dev/null 2>&1; then
  echo "application-default credentails are set"
else
  if [ -f "${CLOUDSDK_CONFIG:-}/application_default_credentials.json" ]; then
    export GOOGLE_APPLICATION_CREDENTIALS=$CLOUDSDK_CONFIG/application_default_credentials.json
  fi
  if gcloud auth application-default print-access-token > /dev/null 2>&1; then
    echo "application-default credentails are set"
  else
    echo "application-default credentails are NOT set. Please follow the prompts to login."
    gcloud auth application-default login
    export GOOGLE_APPLICATION_CREDENTIALS=$CLOUDSDK_CONFIG/application_default_credentials.json
  fi
fi

### STEP 1: Enable GCP APIs

echo "Enabling GCP APIs..."
gcloud services enable storage.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable networkmanagement.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable compute.googleapis.com

### STEP 2: Install Terraform via tfenv and clone/update Granica Setup Repo

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

# Install and use Terraform 1.13.4 idempotently (must match required_version in main.tf)
if ! tfenv list | grep -q "1.13.4"; then
    echo "Installing Terraform 1.13.4..."
    tfenv install 1.13.4
fi
tfenv use 1.13.4

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

cd granica-setup/gcp

### STEP 3: Create GCS Bucket that will host admin server terraform state

# Create the remote state bucket if it doesn't exist
if ! gsutil ls -b gs://$STATE_BUCKET > /dev/null 2>&1; then
    echo "Bucket gs://$STATE_BUCKET does not exist. Creating..."
    gcloud storage buckets create "gs://$STATE_BUCKET" --location="$REGION"
else
    echo "Bucket gs://$STATE_BUCKET already exists."
fi

### STEP 4: Create or update backend.conf

cat > backend.conf <<EOF
bucket = "$STATE_BUCKET"
prefix = "${CUSTOMER_ID}/${DEPLOYMENT_NAME}"
EOF
echo "Updated backend.conf"

### STEP 5: Create or update terraform.tfvars
cat > terraform.tfvars <<EOF
project_id  = "$PROJECT"
region      = "$REGION"
zone        = "$ZONE"
package_url = "$RPM_URL"
server_name = "${CUSTOMER_ID}-${DEPLOYMENT_NAME}"
EOF
echo "Updated terraform.tfvars"

### STEP 6: Deploy

echo "Initializing Terraform with backend configuration..."
terraform init -backend-config=backend.conf

echo "Applying Terraform configuration..."
terraform apply -auto-approve

echo "Deployment complete."
echo "Your Granica Admin Server should now be available as granica-admin-${CUSTOMER_ID}-${DEPLOYMENT_NAME}."
echo "To complete the Granica setup, connect to the instance and run: 'granica deploy --var-file=config.tfvars'"
