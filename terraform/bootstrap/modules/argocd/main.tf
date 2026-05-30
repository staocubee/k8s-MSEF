resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace

    labels = {
      app         = "argocd"
      environment = var.environment
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  create_namespace = false

  timeout = 900
  wait    = true
  atomic  = false

  values = [
    yamlencode({
      crds = {
        install = true
        keep    = false
      }

      server = {
        service = {
          type = "ClusterIP"
        }
      }

      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}


resource "null_resource" "apply_root_app" {
  depends_on = [helm_release.argocd]

  triggers = {
    root_app_sha = filesha256(var.root_app_manifest_path)
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for ArgoCD Application CRD..."
      kubectl wait --for condition=established --timeout=180s crd/applications.argoproj.io

      echo "Waiting for ArgoCD server..."
      kubectl rollout status deployment/argocd-server -n ${var.argocd_namespace} --timeout=300s

      echo "Applying ArgoCD root application..."
      kubectl apply -f ${var.root_app_manifest_path}
    EOT
  }
}