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

variable "node_locations" {
  type = list(string)

  default = [
    "us-central1-a",
    "us-central1-b"
  ]
}

variable "cluster_name" {
  description = "GKE cluster name."
  type        = string
}

variable "network" {
  description = "VPC network name or self link."
  type        = string
}

variable "subnetwork" {
  description = "Subnet name or self link."
  type        = string
}

variable "pods_range_name" {
  description = "Secondary range name for pods."
  type        = string
}

variable "services_range_name" {
  description = "Secondary range name for services."
  type        = string
}

variable "node_machine_type" {
  description = "GKE node machine type."
  type        = string
  default     = "e2-standard-4"
}

variable "node_count" {
  description = "Initial node count."
  type        = number
  default     = 2
}

variable "min_node_count" {
  description = "Minimum node count for autoscaling."
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum node count for autoscaling."
  type        = number
  default     = 3
}

variable "disk_size_gb" {
  description = "Node disk size."
  type        = number
  default     = 50
}