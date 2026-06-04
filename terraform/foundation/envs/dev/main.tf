module "apis" {
  source     = "../../modules/apis"
  project_id = var.project_id
}

module "state_bucket" {
  source      = "../../modules/state-bucket"
  project_id  = var.project_id
  region      = var.region
  bucket_name = var.state_bucket_name

  depends_on = [module.apis]
}

module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
  region     = var.region
  repo_id    = "${var.env}-${var.artifact_registry_repo}"

  depends_on = [module.apis]
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  project_id   = var.project_id
  env          = var.env
  github_owner = var.github_owner
  github_repo  = var.github_repo

  depends_on = [module.apis]
}

module "workload_identity" {
  source = "../../modules/workload-identity"

  project_id                = var.project_id
  env                       = var.env
  workload_service_accounts = var.workload_service_accounts

  depends_on = [module.apis]
}

locals {
  github_actions_member = "serviceAccount:${module.github_oidc.github_actions_service_account_email}"

  workload_identity_iam_bindings = merge([
    for sa_key, sa in module.workload_identity.service_accounts : {
      for role in var.workload_service_accounts[sa_key].roles :
      "${sa_key}-${replace(replace(role, "/", "-"), ".", "-")}" => {
        role   = role
        member = "serviceAccount:${sa.email}"
      }
    }
  ]...)

  github_actions_iam_bindings = {
  github_artifact_registry_writer = {
    role   = "roles/artifactregistry.writer"
    member = local.github_actions_member
  }

  github_container_developer = {
    role   = "roles/container.developer"
    member = local.github_actions_member
  }

  github_container_admin = {
    role   = "roles/container.admin"
    member = local.github_actions_member
  }

  github_compute_network_admin = {
    role   = "roles/compute.networkAdmin"
    member = local.github_actions_member
  }

  github_service_account_user = {
    role   = "roles/iam.serviceAccountUser"
    member = local.github_actions_member
  }

  github_service_account_admin = {
    role   = "roles/iam.serviceAccountAdmin"
    member = local.github_actions_member
  }

  github_project_iam_admin = {
    role   = "roles/resourcemanager.projectIamAdmin"
    member = local.github_actions_member
  }

  github_storage_admin = {
    role   = "roles/storage.admin"
    member = local.github_actions_member
  }

  github_secretmanager_secret_accessor = {
    role   = "roles/secretmanager.secretAccessor"
    member = local.github_actions_member
  }
}
}

module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

  project_iam_bindings = merge(
    local.github_actions_iam_bindings,
    local.workload_identity_iam_bindings
  )

  depends_on = [
    module.github_oidc,
    module.workload_identity
  ]
}