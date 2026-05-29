resource "google_artifact_registry_repository" "docker_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repo_id
  description   = "Docker repository for Kubernetes MSEF thesis workloads"
  format        = "DOCKER"
}