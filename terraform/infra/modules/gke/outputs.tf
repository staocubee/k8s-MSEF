output "cluster_name" {
  value = google_container_cluster.cluster.name
}

output "cluster_location" {
  value = google_container_cluster.cluster.location
}

output "cluster_endpoint" {
  value     = google_container_cluster.cluster.endpoint
  sensitive = true
}

output "node_service_account_email" {
  value = google_service_account.gke_nodes.email
}

output "workload_pool" {
  value = "${var.project_id}.svc.id.goog"
}