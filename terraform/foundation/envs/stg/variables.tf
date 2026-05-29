variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "env" {
  description = "Environment name: dev, stg, or prod."
  type        = string
}

variable "region" {
  description = "Default GCP region."
  type        = string
  default     = "us-central1"
}

variable "github_owner" {
  description = "GitHub organization or username."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "artifact_registry_repo" {
  description = "Artifact Registry repository name."
  type        = string
  default     = "k8s-msef"
}

variable "state_bucket_name" {
  description = "Terraform state bucket name."
  type        = string
}
variable "workload_service_accounts" {
  description = "Google service accounts for GKE Workload Identity."
  type = map(object({
    display_name = string
    roles        = list(string)
  }))
  default = {}
}