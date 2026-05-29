output "bindings" {
  description = "IAM bindings created by this module."
  value = {
    for key, binding in google_project_iam_member.bindings :
    key => {
      role   = binding.role
      member = binding.member
    }
  }
}