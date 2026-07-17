variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "Bucket region."
  type        = string
}

variable "bucket_name" {
  description = "Terraform state bucket name."
  type        = string
}