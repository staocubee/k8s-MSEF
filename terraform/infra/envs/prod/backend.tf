terraform {
  backend "gcs" {
    bucket = "msef-2026-prod-tfstate"
    prefix = "infra/prod"
  }
}