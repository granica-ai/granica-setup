provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "The ID of the project in which to create resources."
  type        = string
}

variable "region" {
  description = "The region in which to create resources."
  type        = string
}

variable "zone" {
  description = "The zone in which to create resources."
  type        = string
}

terraform {
  backend "gcs" {
  }
}

resource "google_compute_network" "vpc_network" {
  name                    = "granica-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_subnet_1" {
  name          = "granica-private-subnet-1"
  ip_cidr_range = "10.47.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
}

resource "google_compute_subnetwork" "private_subnet_2" {
  name          = "granica-private-subnet-2"
  ip_cidr_range = "10.47.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
}

resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  network = google_compute_network.vpc_network.name
  region  = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "nat-config"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_address" "public_ip" {
  name   = "nat-access-ip"
  region = var.region
}

resource "google_service_account" "vm_service_account" {
  account_id   = "admin-server-sa"
  display_name = "Granica Admin Server Service Account"
}

resource "google_project_iam_member" "vm_service_account_admin" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_compute_instance" "vm_instance" {
  name         = "private-vm-instance"
  machine_type = "e2-small"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-stream-8"
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
}

resource "google_compute_firewall" "allow_ingress_from_iap" {
  name    = "allow-ingress-from-iap"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["nat-access"]
}

output "ssh_command" {
  value = "gcloud compute ssh ${google_compute_instance.vm_instance.name} --zone ${google_compute_instance.vm_instance.zone}"
}