resource "google_compute_network" "vpc" {
  project                 = var.project_id
  name                    = "${var.env}-msef-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "gke_subnet" {
  project       = var.project_id
  name          = "${var.env}-msef-gke-subnet"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.vpc_cidr

  secondary_ip_range {
    range_name    = "${var.env}-msef-pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "${var.env}-msef-services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${var.env}-msef-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "${var.env}-msef-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}