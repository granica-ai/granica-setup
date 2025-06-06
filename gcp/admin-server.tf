resource "google_compute_instance" "vm_instance" {
  name         = "granica-admin-server-${var.server_name}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.admin_image_uri
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet_1.self_link
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["iap-access"]

  metadata_startup_script = <<-EOF
  #!/bin/bash

  exec > >(tee /var/log/startup-script.log)
  exec 2>&1

  echo "Starting Granica setup script"

  mkdir -p /home/${var.granica_username}/.project-n
  log="/home/${var.granica_username}/setup-log"
  echo "=== Setup log ===" > $log
  if id ${var.granica_username} &>/dev/null; then
    echo "User exists"
  else
    echo "User does not exist, creating..."
    useradd ${var.granica_username}
  fi
  chown -R ${var.granica_username} /home/${var.granica_username}
  echo $(ls -la /home/${var.granica_username})
  echo $(ls -la /home/${var.granica_username}/.project-n)
  echo '{"default_platform":"gcp"}' > /home/${var.granica_username}/.project-n/config
  echo "vpc_id = \"${google_compute_network.vpc_network.id}\"" > /home/${var.granica_username}/config.tfvars
  echo "private_subnet_ids = [\"${google_compute_subnetwork.private_subnet_1.id}\", \"${google_compute_subnetwork.private_subnet_2.id}\", \"${google_compute_subnetwork.private_subnet_3.id}\"]" >> /home/${var.granica_username}/config.tfvars
  echo "public_subnet_ids = [\"${google_compute_subnetwork.public_subnet_1.id}\"]" >> /home/${var.granica_username}/config.tfvars

  # Check for network connectivity first 
  echo "Checking if Google DNS is reachable..."
  until ping -c 1 8.8.8.8; do
    echo "Waiting for 8.8.8.8 to become reachable..."
    sleep 1
  done
  echo "8.8.8.8 is reachable!"

  echo "Running yum update to catch any recent patches ..."
  sudo yum -y update

  # Install Granica package with retry 
  max_attempts=5
  attempt_num=1
  success=false
  while [ $success = false ] && [ $attempt_num -le $max_attempts ]; do
    echo "Trying download of Granica rpm"
    sudo yum -y install ${var.package_url}
    if [ $? -eq 0 ]; then
      echo "Yum install succeeded"
      success=true
    else
      echo "Attempt $attempt_num failed. Sleeping for 5 seconds and trying again..."
      sleep 5
      ((attempt_num++))
    fi
  done
  
  if [ "$success" = false ]; then
    echo "ERROR: Failed to install Granica package after $max_attempts attempts"
  fi

  echo "Granica setup complete!"
  EOF
}
