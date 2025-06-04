# Custom Image Creation Guide: `granica-admin-server`

This guide documents the steps to create a pre-baked custom CentOS 9 image (`granica-admin-server`) with pre-installed dependencies to speed up Granica admin server provisioning.

## Goal

Reduce setup time from \~30 minutes to under 10 minutes by avoiding full `yum update` and pre-installing essential packages.

---

## Target Project

```
granica-customer-resources
```

---

## Step-by-Step Instructions

### 1. Create a Temporary CentOS 9 VM

```bash
gcloud compute instances create centos-prep-vm \
  --project=granica-customer-resources \
  --zone=us-west2-a \
  --machine-type=e2-standard-2 \
  --image-family=centos-stream-9 \
  --image-project=centos-cloud \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-ssd
```

---

### 2. SSH into the VM

```bash
gcloud compute ssh centos-prep-vm --zone=us-west2-a --project=granica-customer-resources
```

---

### 3. Update System and Install Packages

```bash
# Become root
sudo -i

# Update system
yum -y update

# Install dependencies
dnf install -y python3 python3-pip gcc \
               google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin

# Install Python packages
pip3 install google-cloud-storage pyarrow pandas tabulate

# Clean up cache
yum clean all

# Exit
exit
```

---

### 4. Stop the VM

```bash
gcloud compute instances stop centos-prep-vm --zone=us-west2-a --project=granica-customer-resources
```

---

### 5. Create the Custom Image

```bash
gcloud compute images create granica-admin-server \
  --project=granica-customer-resources \
  --source-disk=centos-prep-vm \
  --source-disk-zone=us-west2-a \
  --family=granica-admin \
  --description="Custom CentOS 9 image with pre-installed dependencies for Granica admin server"
```

---

### 6. Make the Image Publicly Accessible

```bash
gcloud compute images add-iam-policy-binding granica-admin-server \
  --project=granica-customer-resources \
  --member="allAuthenticatedUsers" \
  --role="roles/compute.imageUser"
```

---

### 7. Delete the Temporary VM

```bash
gcloud compute instances delete centos-prep-vm \
  --zone=us-west2-a \
  --project=granica-customer-resources
```

---

## Using This Image in Terraform

```hcl
boot_disk {
  initialize_params {
    image_family  = "granica-admin"
    image_project = "granica-customer-resources"
  }
}
```

---

## Maintenance Tips

* Recreate the image every 2–4 weeks to ensure it's up to date.
