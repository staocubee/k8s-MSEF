variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "github_owner" {
  description = "GitHub owner or organization."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}