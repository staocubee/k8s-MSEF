output "argocd_namespace" {
  value = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_release_name" {
  value = helm_release.argocd.name
}