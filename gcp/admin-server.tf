resource "google_compute_instance" "vm_instance" {
  name         = "granica-admin-server-${var.server_name}"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/stone-bounty-249217/global/images/granica-centos-stream-9-updated"
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

  echo "Starting minimal Granica setup"

  # Reinstall the Granica RPM regardless of image contents
  max_attempts=5
  attempt_num=1
  success=false

  while [ "$success" = false ] && [ $attempt_num -le $max_attempts ]; do
    echo "Attempting to reinstall Granica package"
    sudo yum -y reinstall ${var.package_url}
    if [ $? -eq 0 ]; then
      echo "Granica package reinstall succeeded"
      success=true
    else
      echo "Attempt $attempt_num failed. Sleeping and retrying..."
      sleep 5
      ((attempt_num++))
    fi
  done

  if [ "$success" = false ]; then
    echo "ERROR: Granica package reinstall failed after $max_attempts attempts"
  fi

  echo "Granica RPM reinstall complete"
  EOF
}
