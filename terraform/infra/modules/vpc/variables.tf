variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "env" {
  description = "Environment name."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
}

variable "vpc_cidr" {
  description = "Primary subnet CIDR."
  type        = string
}

variable "pods_cidr" {
  description = "Secondary CIDR for GKE pods."
  type        = string
}

variable "services_cidr" {
  description = "Secondary CIDR for GKE services."
  type        = string
}