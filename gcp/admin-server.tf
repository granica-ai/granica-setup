resource "google_compute_instance" "vm_instance" {
  name         = "private-vm-instance"
  machine_type = "e2-small"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.boot_image
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet_1.self_link
    access_config {
      nat_ip = google_compute_address.public_ip.address
    }
  }

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["nat-access"]

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e
    mkdir -p /home/${var.granica_username}/.project-n
    log="/home/${var.granica_username}/setup-log"
    echo "=== Setup log ===" > $log
    useradd ${var.granica_username} 2>> $log
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
    sudo yum -y install ${var.package_url} 2>> $log

  EOF
}

output "ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.vm_instance.name} --zone ${google_compute_instance.vm_instance.zone}"
}