variable "argocd_namespace" {
  description = "Namespace where ArgoCD will be installed."
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version."
  type        = string
  default     = "7.7.16"
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

variable "environment" {
  description = "Environment name: dev, stg, prod."
  type        = string
}

variable "root_app_path" {
  description = "Path to the root ArgoCD app for this environment."
  type        = string
}

variable "root_app_manifest_path" {
  description = "Local path to the ArgoCD root application manifest."
  type        = string
}