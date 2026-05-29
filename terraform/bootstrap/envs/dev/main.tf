module "argocd" {
  source = "../../modules/argocd"

  environment     = var.env
  repo_url        = var.repo_url
  target_revision = var.target_revision
  root_app_path   = var.root_app_path
}