data "terraform_remote_state" "bootstrap" {

  backend = "gcs"
  config = {
    bucket = var.state_bucket_name
    prefix = "bootstrap-state/${var.env}"
  }

}

module "workload_identity" {

  source = "../../modules/workload-identity"
  project_id = var.project_id
  env = var.env
  workload_service_accounts = var.workload_service_accounts

}

locals {

  workload_identity_iam_bindings = merge([

    for sa_key, sa in module.workload_identity.service_accounts : {

      for role in var.workload_service_accounts[sa_key].roles :

      "${sa_key}-${replace(replace(role, "/", "-"), ".", "-")}" => {

        role   = role

        member = "serviceAccount:${sa.email}"

      }

    }

  ]...)

}

module "iam" {

  source = "../../modules/iam"

  project_id = var.project_id

  project_iam_bindings = local.workload_identity_iam_bindings

  depends_on = [
    module.workload_identity
  ]

}