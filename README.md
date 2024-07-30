## Granica Admin Server

Build the Granica Admin Server.
You can run this from AWS or Google Cloud Shell or from your laptop

## Getting Started

Please read the following instructions

### Prerequisites for AWS


If you are working out AWS Cloud Shell you must be logged in as Admin. If you are running from your laptop you will need AWS command line credentials that gives administrator access

### Instructions

1. Install Terraform from Cloud Shell or on your laptop
```bash
$ git clone https://github.com/tfutils/tfenv.git ~/.tfenv
$ mkdir ~/bin
$ ln -s ~/.tfenv/bin/* ~/bin/
$ tfenv install
$ tfenv use 1.9.3
$ terraform --version
Terraform v1.9.3 on linux_amd64
```
2. Create S3 Bucket that will host admin server terraform state
3. Provide the following parameters in `backend.conf`
```bash
      bucket = <name of bucket that will host admin server tf state>
      region = <region where Granica product will be installed>
```
4. Run the following
```terraform
terraform init -backend-config=backend.conf
terraform apply

```
5. Provide values for the parameters in the `terraform.tfvars` file
```bash
aws_region     = "region like us-east-1, or us-west-2, etc"
package_url    = "https://granica.ai/granica.rpm"
```

