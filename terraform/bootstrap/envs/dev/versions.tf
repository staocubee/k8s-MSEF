terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  backend "gcs" {
    bucket = "msef-2026-dev-tfstate"
    prefix = "bootstrap/dev"
  }
}