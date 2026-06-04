variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "project_iam_bindings" {
  description = "Project-level IAM bindings. Map key is a logical name."
  type = map(object({
    role   = string
    member = string
  }))
  default = {}
}
