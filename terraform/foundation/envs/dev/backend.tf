terraform {
  backend "gcs" {
    bucket = "msef-2026-dev-tfstate"
    prefix = "foundation/dev"
  }
}