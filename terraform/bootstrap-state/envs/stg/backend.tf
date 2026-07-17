terraform {
  backend "gcs" {
    bucket = "msef-2026-stg-tfstate"
    prefix = "foundation/stg"
  }
}