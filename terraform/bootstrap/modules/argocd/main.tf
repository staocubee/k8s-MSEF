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

  values = [
    yamlencode({
      global = {
        domain = ""
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

resource "kubernetes_manifest" "root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "${var.environment}-root-app"
      namespace = var.argocd_namespace
    }

    spec = {
      project = "default"

      source = {
        repoURL        = var.repo_url
        targetRevision = var.target_revision
        path           = var.root_app_path
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.argocd_namespace
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }

        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }

  depends_on = [helm_release.argocd]
}