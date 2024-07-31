provider "google" {
  project = var.project_id
  region  = var.region
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

resource "google_compute_subnetwork" "private_subnet_3" {
  name          = "granica-private-subnet-3"
  ip_cidr_range = "10.47.3.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
}

resource "google_compute_subnetwork" "public_subnet_1" {
  name          = "granica-public-subnet-1"
  ip_cidr_range = "10.47.4.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
  private_ip_google_access = false

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

resource "google_project_iam_member" "project_permissions" {
  for_each = toset([
    "roles/container.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/logging.configWriter",
    "roles/storage.admin",
    "roles/compute.admin",
    "roles/pubsub.admin"
  ])
  role    = each.value
  project = var.project_id
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
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

