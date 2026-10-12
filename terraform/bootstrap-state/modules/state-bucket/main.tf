resource "google_storage_bucket" "tfstate" {
  project  = var.project_id
  name     = var.bucket_name
  location = var.region

  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  # Keep the live state forever. Prune only superseded (noncurrent) versions:
  # keep the newest 20, and delete any noncurrent version older than 90 days.
  lifecycle_rule {
    condition {
      num_newer_versions = 20
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 90
      with_state                 = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }
}