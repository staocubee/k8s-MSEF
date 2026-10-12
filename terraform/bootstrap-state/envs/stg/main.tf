# Bootstrap layer: everything CI needs before it can run.
# Applied ONCE by a human project owner (Cloud Shell), not by CI: it creates the
# Workload Identity pool that CI itself authenticates through. See docs/GCP-BOOTSTRAP.md.
# Workload service accounts are owned by terraform/foundation, not here.

module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
}

module "state_bucket" {
  source      = "../../modules/state-bucket"
  project_id  = var.project_id
  region      = var.region
  bucket_name = var.state_bucket_name
  depends_on  = [module.apis]
}

module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
  repo_id    = "${var.env}-${var.artifact_registry_repo}"
  depends_on = [module.apis]
}

module "github_oidc" {
  source       = "../../modules/github-oidc"
  project_id   = var.project_id
  env          = var.env
  github_owner = var.github_owner
  github_repo  = var.github_repo
  depends_on   = [module.apis]
}

locals {
  github_actions_member = "serviceAccount:${module.github_oidc.github_actions_service_account_email}"

  # Roles the GitHub Actions service account needs for the workflows it runs:
  #   terraform-foundation : create workload GSAs and their project IAM bindings
  #   terraform-infra      : VPC, subnet, router, NAT, GKE cluster, node pool, node GSA
  #   terraform-bootstrap  : install Argo CD (cluster-scoped RBAC objects)
  #   security workflows   : apply policies and manifests, read results
  #   build workflows      : push images
  #   bootstrap-state      : plan only (read access)
  # resourcemanager.projectIamAdmin is powerful (it can grant roles); acceptable
  # for a single-purpose research project, revisit for anything shared.
  github_actions_roles = [
    "roles/viewer",
    "roles/artifactregistry.writer",
    "roles/container.admin",
    "roles/compute.networkAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/resourcemanager.projectIamAdmin",
    "roles/storage.admin",
    "roles/secretmanager.secretAccessor",
  ]
}

module "iam" {
  source     = "../../modules/iam"
  project_id = var.project_id
  project_iam_bindings = {
    for r in local.github_actions_roles :
    "github-${replace(replace(r, "roles/", ""), ".", "-")}" => { role = r, member = local.github_actions_member }
  }
  depends_on = [module.github_oidc]
}
