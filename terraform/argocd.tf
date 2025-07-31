# ArgoCD Namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
    
    labels = {
      "name" = var.argocd_namespace
    }
  }

  depends_on = [module.eks]
}

# ArgoCD Helm Release
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      # Global configuration
      global = {
        image = {
          tag = var.argocd_image_tag
        }
      }

      # Server configuration
      server = {
        # Service configuration - use LoadBalancer for easy access
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
          }
        }
        
        # Basic configuration
        config = {
          # Repository configuration
          "repositories" = yamlencode([
            {
              url = var.git_repository_url
              name = "infrastructure-repo"
              type = "git"
            }
          ])
          
          # Application configuration
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
        }
        
        # Command line arguments
        extraArgs = [
          "--insecure"  # For development - remove in production with proper TLS
        ]
      }

      # Controller configuration
      controller = {
        resources = {
          limits = {
            cpu = "1000m"
            memory = "1Gi"
          }
          requests = {
            cpu = "250m"
            memory = "512Mi"
          }
        }
      }

      # Repository server configuration
      repoServer = {
        resources = {
          limits = {
            cpu = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu = "100m"
            memory = "256Mi"
          }
        }
      }

      # Redis configuration
      redis = {
        enabled = true
        resources = {
          limits = {
            cpu = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu = "100m"
            memory = "128Mi"
          }
        }
      }

      # ApplicationSet controller
      applicationSet = {
        enabled = true
      }

      # Disable Dex for simplicity
      dex = {
        enabled = false
      }
    })
  ]

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    kubernetes_namespace.argocd,
    module.eks
  ]
}

# Secret for Git repository access (if using private repository)
resource "kubernetes_secret" "git_repository" {
  count = var.git_repository_private ? 1 : 0
  
  metadata {
    name      = "git-repository-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = var.git_repository_url
    username = var.git_username
    password = var.git_token
  }

  depends_on = [
    helm_release.argocd
  ]
}

# Wait for ArgoCD to be ready
resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  create_duration = "60s"
}

