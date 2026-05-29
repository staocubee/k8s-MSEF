resource "google_service_account" "workload_gsa" {
  for_each = var.workload_service_accounts

  project      = var.project_id
  account_id   = "${var.env}-${each.key}"
  display_name = each.value.display_name
}

locals {
  workload_iam_bindings = flatten([
    for sa_key, sa_value in var.workload_service_accounts : [
      for role in sa_value.roles : {
        sa_key = sa_key
        role   = role
      }
    ]
  ])
}

resource "google_project_iam_member" "workload_roles" {
  for_each = {
    for binding in local.workload_iam_bindings :
    "${binding.sa_key}-${replace(binding.role, "/", "-")}" => binding
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.workload_gsa[each.value.sa_key].email}"
}