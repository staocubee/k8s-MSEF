output "repository_name" {
  value = google_artifact_registry_repository.docker_repo.name
}

output "repository_id" {
  value = google_artifact_registry_repository.docker_repo.repository_id
}

output "location" {
  value = google_artifact_registry_repository.docker_repo.location
}