data "google_project" "current" {
  project_id = var.project_id
}

resource "google_service_account" "github_actions" {
  project      = var.project_id
  account_id   = "${var.env}-github-actions"
  display_name = "${var.env} GitHub Actions service account"
  description  = "Service account used by GitHub Actions for Terraform, image push, and GKE deployment."
}

resource "google_iam_workload_identity_pool" "github_pool" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.env}-github-pool"
  display_name              = "${var.env} GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions OIDC"
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.env}-github-provider"
  display_name                       = "${var.env} GitHub Actions Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "attribute.repository == '${var.github_owner}/${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "github_oidc_binding" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"

  member = "principalSet://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github_pool.workload_identity_pool_id}/attribute.repository/${var.github_owner}/${var.github_repo}"
}