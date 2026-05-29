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
  description = "Pods secondary range CIDR."
  type        = string
}

variable "services_cidr" {
  description = "Services secondary range CIDR."
  type        = string
}

variable "node_machine_type" {
  description = "GKE node machine type."
  type        = string
}

variable "node_count" {
  description = "Initial node count."
  type        = number
}

variable "min_node_count" {
  description = "Minimum node count."
  type        = number
}

variable "max_node_count" {
  description = "Maximum node count."
  type        = number
}