resource "google_project_iam_member" "bindings" {
  for_each = var.project_iam_bindings

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}