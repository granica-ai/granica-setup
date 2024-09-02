## Granica GCP Admin Server

### Prerequisites
If you are working in Cloud Shell you must be logged in as Admin. If you are running from your laptop you will need GCloud command line credentials that gives administrator access.
- GCP Project

### Instructions
1. Enable GCP APIs
```bash
$ gcloud services enable compute.googleapis.com
$ gcloud services enable storage.googleapis.com
$ gcloud services enable iam.googleapis.com
$ gcloud services enable cloudresourcemanager.googleapis.com
$ gcloud services enable networkmanagement.googleapis.com
$ gcloud services enable container.googleapis.com
$ gcloud services enable logging.googleapis.com
$ gcloud services enable pubsub.googleapis.com
```

2. Install Terraform on Cloud Shell or on your laptop
```bash
$ git clone https://github.com/tfutils/tfenv.git ~/.tfenv
$ mkdir ~/bin
$ ln -s ~/.tfenv/bin/* ~/bin/
$ tfenv install
$ tfenv use 1.9.3
$ terraform --version
Terraform v1.9.3 on linux_amd64
```

3. Create GCS Bucket that will host admin server terraform state
   `gcloud storage buckets create <bucket-name> --location <region>`

4. Provide the following parameters in `backend.conf`
```bash
      bucket = <name of bucket that will host admin server tf state>
      prefix = <prefix to store state>
```

4. Provide values for the parameters in the `terraform.tfvars` file
```bash
project_id     = "your-gcp-project-id"
region         = "us-west2"
zone           = "us-west2-a"
package_url    = "https://granica.ai/granica.rpm"
```

5. Run the following
```terraform
terraform init -backend-config=backend.conf
terraform apply
```

6. Login to the Admin Server
```bash
(Use the gcloud command output at the end of the terraform apply to ssh into the admin server)
$ sudo su - granica # Use granica user to run granica commands
# Check if the granica RPM has finished installation (tail -f /var/log/dnf.rpm.log)
$ granica --help
$ granica deploy --var-file config.tfvars
```