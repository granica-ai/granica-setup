resource "google_compute_instance" "vm_instance" {
  name         = "granica-admin-server"
  machine_type = "e2-small"
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
    sudo yum -y update
    sudo dnf install -y google-cloud-cli 2>> $log
    sudo dnf install -y google-cloud-cli-gke-gcloud-auth-plugin 2>> $log
    sudo yum -y install java-11-openjdk-devel python3 python3-pip python3-devel gcc 2>> $log
    sudo -u ${var.granica_username} bash -c "
      cd /home/${var.granica_username}
      python3 -m venv venv
      source venv/bin/activate
      pip install --upgrade pip
      pip install 'google-cloud-storage>=2.10.0' 'pyarrow>=14.0.0' 'pyspark>=3.4.0' 'delta-spark>=2.4.0' 'pandas>=2.0.0'
    " 2>> $log
    echo "alias activate-granica='source /home/${var.granica_username}/venv/bin/activate'" >> /home/${var.granica_username}/.bashrc
    echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" >> /home/${var.granica_username}/.bashrc
    sudo yum -y install ${var.package_url} 2>> $log
  EOF
}
