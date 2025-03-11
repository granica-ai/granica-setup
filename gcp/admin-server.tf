resource "google_compute_instance" "vm_instance" {
  name         = "granica-admin-server-${var.server_name}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.boot_image
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
    set -e
    mkdir -p /home/${var.granica_username}/.project-n
    log="/home/${var.granica_username}/setup-log"
    echo "=== Setup log ===" > $log
    if id ${var.granica_username} &>/dev/null; then
      echo "User exists" 2>> $log
    else
      echo "User does not exist, creating..." 2>> $log
      useradd ${var.granica_username} 2>> $log
    fi
    chown -R ${var.granica_username} /home/${var.granica_username} 2>> $log
    echo $(ls -la /home/${var.granica_username}) >> $log
    echo $(ls -la /home/${var.granica_username}/.project-n) >> $log
    echo '{"default_platform":"gcp"}' > /home/${var.granica_username}/.project-n/config 2>> $log
    echo "vpc_id = \"${google_compute_network.vpc_network.id}\"" > /home/${var.granica_username}/config.tfvars
    echo "private_subnet_ids = [\"${google_compute_subnetwork.private_subnet_1.id}\", \"${google_compute_subnetwork.private_subnet_2.id}\", \"${google_compute_subnetwork.private_subnet_3.id}\"]" >> /home/${var.granica_username}/config.tfvars
    echo "public_subnet_ids = [\"${google_compute_subnetwork.public_subnet_1.id}\"]" >> /home/${var.granica_username}/config.tfvars
    
    # Check for network connectivity first (like AWS)
    echo "Checking if Google DNS is reachable..." >> $log
    until ping -c 1 8.8.8.8; do
      echo "Waiting for 8.8.8.8 to become reachable..." >> $log
      sleep 1
    done
    echo "8.8.8.8 is reachable!" >> $log
    
    # System update with retry (like AWS)
    max_attempts=5
    attempt_num=1
    success=false
    while [ $success = false ] && [ $attempt_num -le $max_attempts ]; do
      echo "Trying yum update and install of dependencies" >> $log
      sudo yum -y update
      sudo dnf install -y google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin python3 python3-pip python3-devel gcc
      if [ $? -eq 0 ]; then
        echo "Yum update and install succeeded" >> $log
        success=true
      else
        echo "Attempt $attempt_num failed. Sleeping for 5 seconds and trying again..." >> $log
        sleep 5
        ((attempt_num++))
      fi
    done
    
    # Install Python packages with retry (like AWS)
    max_attempts=5
    attempt_num=1
    success=false
    while [ $success = false ] && [ $attempt_num -le $max_attempts ]; do
      echo "Trying to install Python packages" >> $log
      sudo pip3 install google-cloud-storage pyarrow pandas
      if [ $? -eq 0 ]; then
        echo "Python packages install succeeded" >> $log
        success=true
      else
        echo "Attempt $attempt_num failed. Sleeping for 5 seconds and trying again..." >> $log
        sleep 5
        ((attempt_num++))
      fi
    done
    
    # Install Granica package with retry (like AWS)
    max_attempts=5
    attempt_num=1
    success=false
    while [ $success = false ] && [ $attempt_num -le $max_attempts ]; do
      echo "Trying download of Granica rpm" >> $log
      sudo yum -y install ${var.package_url}
      if [ $? -eq 0 ]; then
        echo "Yum install succeeded" >> $log
        success=true
      else
        echo "Attempt $attempt_num failed. Sleeping for 5 seconds and trying again..." >> $log
        sleep 5
        ((attempt_num++))
      fi
    done
  EOF
}
