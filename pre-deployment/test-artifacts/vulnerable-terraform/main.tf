terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "demo-project"
  region  = "us-central1"
}

#########################################################
# PUBLIC STORAGE BUCKET
#########################################################

resource "google_storage_bucket" "public_bucket" {

  name     = "msef-public-bucket-demo"

  location = "US"

  uniform_bucket_level_access = false

  public_access_prevention = "inherited"

  force_destroy = true
}

resource "google_storage_bucket_iam_member" "public_access" {

  bucket = google_storage_bucket.public_bucket.name

  role = "roles/storage.objectViewer"

  member = "allUsers"

}

#########################################################
# UNENCRYPTED DISK
#########################################################

resource "google_compute_disk" "disk" {

  name = "unencrypted-disk"

  type = "pd-standard"

  zone = "us-central1-a"

  size = 100

}

#########################################################
# OPEN FIREWALL
#########################################################

resource "google_compute_firewall" "allow_all" {

  name = "allow-all"

  network = "default"

  direction = "INGRESS"

  source_ranges = [

    "0.0.0.0/0"

  ]

  allow {

    protocol = "tcp"

    ports = [

      "22",

      "80",

      "443"

    ]

  }

}

#########################################################
# EXCESSIVE IAM
#########################################################

resource "google_project_iam_member" "owner" {

  project = "demo-project"

  role = "roles/owner"

  member = "user:test@example.com"

}

#########################################################
# PUBLIC VM
#########################################################

resource "google_compute_instance" "public_vm" {

  name = "public-vm"

  machine_type = "e2-micro"

  zone = "us-central1-a"

  tags = [

    "http-server"

  ]

  boot_disk {

    initialize_params {

      image = "debian-cloud/debian-12"

    }

  }

  network_interface {

    network = "default"

    access_config {}

  }

}

#########################################################
# GKE WITHOUT PRIVATE NODES
#########################################################

resource "google_container_cluster" "cluster" {

  name = "vulnerable-cluster"

  location = "us-central1"

  deletion_protection = false

  remove_default_node_pool = true

  initial_node_count = 1

  network = "default"

}