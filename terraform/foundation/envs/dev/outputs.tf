output "workload_identity_service_accounts" {
  description = "Workload Identity service accounts"
  value       = module.workload_identity.service_accounts
}

output "iam_bindings" {
  description = "Project IAM bindings"
  value       = module.iam.bindings
}