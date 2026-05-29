resource "google_container_node_pool" "primary" {
  project  = var.project_id
  name     = "${var.env}-msef-node-pool"
  cluster  = google_container_cluster.cluster.name
  location = var.region

  initial_node_count = var.node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = var.disk_size_gb
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_nodes.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      environment = var.env
      project     = "k8s-msef"
    }

    tags = [
      "${var.env}-msef-gke-node"
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}