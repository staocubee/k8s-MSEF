variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "workload_service_accounts" {
  description = "Map of workload identity service accounts and IAM roles."
  type = map(object({
    display_name = string
    roles        = list(string)
  }))
}