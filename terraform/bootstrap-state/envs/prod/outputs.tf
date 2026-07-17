output "artifact_registry_repository" {
  value = module.artifact_registry.repository_name
}

output "artifact_registry_location" {
  value = module.artifact_registry.location
}

output "github_actions_service_account" {
  value = module.github_oidc.github_actions_service_account_email
}

output "workload_identity_provider" {
  value = module.github_oidc.workload_identity_provider_name
}

output "state_bucket_name" {
  value = module.state_bucket.bucket_name
}
output "workload_identity_service_accounts" {
  value = module.workload_identity.service_accounts
}
output "iam_bindings" {
  value = module.iam.bindings
}