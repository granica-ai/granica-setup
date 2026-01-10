## Granica GCP Admin Server

### Prerequisites
If you are working in Cloud Shell you must be logged in as Admin. If you are running from your laptop you will need GCloud command line credentials that gives administrator access.
- create your own GCP Project (by default you will have the admin access for this project)

### Instructions

1. Enable GCP APIs
   ```bash
   gcloud services enable storage.googleapis.com
   gcloud services enable iam.googleapis.com
   gcloud services enable cloudresourcemanager.googleapis.com
   gcloud services enable networkmanagement.googleapis.com
   gcloud services enable container.googleapis.com
   gcloud services enable logging.googleapis.com
   gcloud services enable pubsub.googleapis.com
   gcloud services enable compute.googleapis.com
   gcloud services enable sqladmin.googleapis.com
   gcloud services enable servicenetworking.googleapis.com
   ```

2. Install Terraform on Cloud Shell or on your laptop
   ```bash
   git clone https://github.com/tfutils/tfenv.git ~/.tfenv
   mkdir ~/bin
   ln -s ~/.tfenv/bin/* ~/bin/
   export PATH="$HOME/.tfenv/bin:$PATH"
   tfenv install 1.13.4
   tfenv use 1.13.4
   terraform --version
   git clone https://github.com/granica-ai/granica-setup.git
   cd granica-setup/gcp
   ```

3. Create GCS Bucket that will host admin server terraform state
   ```bash
   gcloud storage buckets create gs://<bucket-name> --location <region>
   ```

4. Provide the following parameters in `backend.conf`
   ```bash
   bucket = <name of bucket that will host admin server tf state>
   prefix = <prefix to store state>
   ```

5. Provide values for the parameters in the `terraform.tfvars` file
   ```bash
   project_id     = "your-gcp-project-id"
   region         = "us-central1"
   zone           = "us-central1-a"
   package_url    = "https://granica.ai/granica.rpm"
   server_name    = "CHANGE_ME"
   ```

6. Run the following
   ```bash
   terraform init -backend-config=backend.conf
   terraform apply
   ```

7. Login to the Admin Server
   ```bash
   gcloud compute ssh granica-admin-server-{server_name} --project=<project-id> --zone=<zone> --tunnel-through-iap

   # server_name is what you provided in the terraform.tfvars file
   ```
   (Use the gcloud command output at the end of the terraform apply to ssh into the admin server)
   ```bash
   $ sudo su - granica # Use granica user to run granica commands
   # Check if the granica RPM has finished installation will take around 10-15 mins to get installed.
   # Can check the logs here (tail -f /var/log/dnf.rpm.log  --> to see more debug logs tail -f /var/log/startup-script.log)
   $ granica --help
   $ granica deploy --var-file config.tfvars
   # Will take around 10-15 mins for the clusters to be deployed
   ```
