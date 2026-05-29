output "network_name" {
  value = google_compute_network.vpc.name
}

output "network_id" {
  value = google_compute_network.vpc.id
}

output "subnet_name" {
  value = google_compute_subnetwork.gke_subnet.name
}

output "subnet_id" {
  value = google_compute_subnetwork.gke_subnet.id
}

output "pods_range_name" {
  value = "${var.env}-msef-pods"
}

output "services_range_name" {
  value = "${var.env}-msef-services"
}