module "argocd" {
  source = "../../modules/argocd"

  providers = {
    google     = google
    kubernetes = kubernetes
    helm       = helm
  }
  environment            = var.env
  repo_url               = var.repo_url
  target_revision        = var.target_revision
  root_app_path          = var.root_app_path
  root_app_manifest_path = var.root_app_manifest_path
}