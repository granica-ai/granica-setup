terraform {
  required_version = "~> 1.13"

  backend "gcs" {
  }
}

# Provider alias for getting identity (used by data source)
provider "google" {
  alias   = "identity"
  project = var.project_id
  region  = var.region
}

# Get current GCP caller identity for owner_id
data "google_client_openid_userinfo" "me" {
  provider = google.identity
}

# Sanitize email for GCP label constraints (lowercase, alphanumeric, underscores, dashes only, max 63 chars)
locals {
  sanitized_owner_id = substr(
    replace(
      replace(
        lower(data.google_client_openid_userinfo.me.email),
        "@", "-at-"
      ),
      ".", "-"
    ),
    0,
    63
  )
}

# Main provider with default_labels
provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    admin_server_name = "granica-admin-${var.server_name}"
    owner_id          = local.sanitized_owner_id
  }
}

resource "google_compute_network" "vpc_network" {
  name                    = "granica-vpc-${var.server_name}"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_subnet_1" {
  name          = "granica-vpc-${var.server_name}-private-subnet-1"
  ip_cidr_range = "10.47.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
}

resource "google_compute_subnetwork" "private_subnet_2" {
  name          = "granica-vpc-${var.server_name}-private-subnet-2"
  ip_cidr_range = "10.47.2.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
}

resource "google_compute_subnetwork" "private_subnet_3" {
  name          = "granica-vpc-${var.server_name}-private-subnet-3"
  ip_cidr_range = "10.47.3.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.self_link
}

resource "google_compute_subnetwork" "public_subnet_1" {
  name                     = "granica-vpc-${var.server_name}-public-subnet-1"
  ip_cidr_range            = "10.47.4.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc_network.self_link
  private_ip_google_access = false
}

resource "google_compute_router" "nat_router" {
  name    = "granica-vpc-${var.server_name}-nat-router"
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

resource "google_service_account" "vm_service_account" {
  account_id   = "granica-admin-${var.server_name}-sa"
  display_name = "Granica Admin Server Service Account - ${var.server_name}"
}

resource "google_project_iam_member" "project_permissions" {
  for_each = toset([
    "roles/container.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/logging.configWriter",
    "roles/storage.admin",
    "roles/compute.admin",
    "roles/pubsub.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/iam.serviceAccountUser",
    "roles/cloudsql.admin",
    "roles/compute.networkAdmin"
  ])
  role    = each.value
  project = var.project_id
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_compute_firewall" "allow_ingress_from_iap" {
  name    = "granica-vpc-${var.server_name}-allow-ingress-from-iap"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22", "3389"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["iap-access"]
}
