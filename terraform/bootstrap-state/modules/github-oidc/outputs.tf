output "github_actions_service_account_email" {
  description = "GitHub Actions Service Account email"
  value       = google_service_account.github_actions.email
}

output "github_actions_service_account_name" {
  description = "GitHub Actions Service Account name"
  value       = google_service_account.github_actions.name
}

output "github_actions_service_account_id" {
  description = "GitHub Actions Service Account ID"
  value       = google_service_account.github_actions.account_id
}

output "workload_identity_pool_id" {
  description = "Workload Identity Pool ID"
  value       = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
}

output "workload_identity_pool_name" {
  description = "Workload Identity Pool resource name"
  value       = google_iam_workload_identity_pool.github_pool.name
}

output "workload_identity_provider_name" {
  description = "Workload Identity Provider resource name"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "workload_identity_provider_id" {
  description = "Workload Identity Provider ID"
  value       = google_iam_workload_identity_pool_provider.github_provider.workload_identity_pool_provider_id
}