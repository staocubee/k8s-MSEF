output "artifact_registry_repository" {
  value = module.artifact_registry.repository_name
}

output "artifact_registry_location" {
  value = module.artifact_registry.location
}

output "github_actions_service_account" {
  description = "GitHub variable GCP_SERVICE_ACCOUNT"
  value       = module.github_oidc.github_actions_service_account_email
}

output "workload_identity_provider" {
  description = "GitHub variable GCP_WORKLOAD_IDENTITY_PROVIDER"
  value       = module.github_oidc.workload_identity_provider_name
}

output "state_bucket_name" {
  value = module.state_bucket.bucket_name
}

output "iam_bindings" {
  value = module.iam.bindings
}
