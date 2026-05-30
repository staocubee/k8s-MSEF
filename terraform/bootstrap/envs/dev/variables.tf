variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
}

variable "repo_url" {
  description = "Git repository URL containing GitOps manifests."
  type        = string
}

variable "target_revision" {
  description = "Git revision or branch."
  type        = string
  default     = "main"
}

variable "root_app_path" {
  description = "Path to the root app for this environment."
  type        = string
}

variable "root_app_manifest_path" {
  description = "Path to the root app manifest."
  type        = string
}