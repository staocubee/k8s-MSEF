project_id             = "msef-2026"
region                 = "us-central1"
github_owner           = "staocubee"
env                    = "stg"
github_repo            = "k8s-MSEF"
artifact_registry_repo = "k8s-msef"
state_bucket_name      = "msef-2026-stg-tfstate"
workload_service_accounts = {
  external-secrets = {
    display_name = "stg External Secrets GSA"
    roles = [
      "roles/secretmanager.secretAccessor"
    ]
  }

  cert-manager = {
    display_name = "stg Cert Manager GSA"
    roles = [
      "roles/dns.admin"
    ]
  }

  argocd = {
    display_name = "stg ArgoCD GSA"
    roles = [
      "roles/artifactregistry.reader"
    ]
  }

  workload-app = {
    display_name = "stg Application Workload GSA"
    roles = [
      "roles/artifactregistry.reader",
      "roles/secretmanager.secretAccessor"
    ]
  }
}