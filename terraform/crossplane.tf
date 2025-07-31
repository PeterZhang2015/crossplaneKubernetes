# Crossplane Namespace
resource "kubernetes_namespace" "crossplane_system" {
  metadata {
    name = var.crossplane_namespace
    
    labels = {
      "name" = var.crossplane_namespace
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit" = "privileged"
      "pod-security.kubernetes.io/warn" = "privileged"
    }
  }

  depends_on = [module.eks]
}

# Crossplane Helm Release
resource "helm_release" "crossplane" {
  name       = "crossplane"
  repository = "https://charts.crossplane.io/stable"
  chart      = "crossplane"
  version    = var.crossplane_chart_version
  namespace  = kubernetes_namespace.crossplane_system.metadata[0].name

  # Crossplane configuration values
  values = [
    yamlencode({
      # Resource limits and requests
      resourcesCrossplane = {
        limits = {
          cpu    = "500m"
          memory = "1Gi"
        }
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
      }

      resourcesRBACManager = {
        limits = {
          cpu    = "100m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
      }

      # Enable package manager
      packageManager = {
        enable = true
      }

      # Security context
      securityContextCrossplane = {
        runAsUser = 65532
        runAsGroup = 65532
        allowPrivilegeEscalation = false
        readOnlyRootFilesystem = true
        runAsNonRoot = true
        seccompProfile = {
          type = "RuntimeDefault"
        }
        capabilities = {
          drop = ["ALL"]
        }
      }

      # Metrics and monitoring
      metrics = {
        enabled = true
      }

      # Args for additional configuration
      args = [
        "--debug",
        "--enable-composition-revisions",
        "--enable-environment-configs"
      ]

      # Node selector for management nodes
      nodeSelector = {
        "kubernetes.io/os" = "linux"
      }

      # Tolerations for system workloads
      tolerations = [
        {
          key = "CriticalAddonsOnly"
          operator = "Exists"
        }
      ]

      # Affinity rules
      affinity = {
        nodeAffinity = {
          preferredDuringSchedulingIgnoredDuringExecution = [
            {
              weight = 100
              preference = {
                matchExpressions = [
                  {
                    key = "node-role.kubernetes.io/control-plane"
                    operator = "Exists"
                  }
                ]
              }
            }
          ]
        }
      }
    })
  ]

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  depends_on = [
    kubernetes_namespace.crossplane_system,
    module.eks
  ]
}

# Service Account for Crossplane with IRSA
resource "kubernetes_service_account" "crossplane" {
  metadata {
    name      = "crossplane"
    namespace = kubernetes_namespace.crossplane_system.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.crossplane_irsa.arn
    }
    
    labels = {
      "app.kubernetes.io/name" = "crossplane"
      "app.kubernetes.io/component" = "cloud-infrastructure-controller"
    }
  }

  depends_on = [
    helm_release.crossplane,
    aws_iam_role.crossplane_irsa
  ]
}

# ClusterRoleBinding for Crossplane service account
resource "kubernetes_cluster_role_binding" "crossplane" {
  metadata {
    name = "crossplane"
    
    labels = {
      "app.kubernetes.io/name" = "crossplane"
      "app.kubernetes.io/component" = "cloud-infrastructure-controller"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "crossplane"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.crossplane.metadata[0].name
    namespace = kubernetes_service_account.crossplane.metadata[0].namespace
  }

  depends_on = [
    kubernetes_service_account.crossplane,
    helm_release.crossplane
  ]
}

# Wait for Crossplane to be ready
resource "time_sleep" "wait_for_crossplane" {
  depends_on = [helm_release.crossplane]
  create_duration = "60s"
}

# Crossplane Configuration for AWS Provider
resource "kubernetes_manifest" "crossplane_config" {
  manifest = {
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Configuration"
    metadata = {
      name = "platform-configuration"
      namespace = kubernetes_namespace.crossplane_system.metadata[0].name
    }
    spec = {
      package = "xpkg.upbound.io/upbound/platform-ref-aws:v0.7.0"
      packagePullPolicy = "IfNotPresent"
      revisionActivationPolicy = "Automatic"
      revisionHistoryLimit = 3
    }
  }

  depends_on = [
    time_sleep.wait_for_crossplane
  ]
}

# Network Policy for Crossplane namespace (if network policies are enabled)
resource "kubernetes_network_policy" "crossplane_system" {
  metadata {
    name      = "crossplane-system-network-policy"
    namespace = kubernetes_namespace.crossplane_system.metadata[0].name
  }

  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]

    # Allow ingress from kube-system for metrics scraping
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      
      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }

    # Allow egress to API server and external registries
    egress {
      # Allow DNS
      to {}
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }

    egress {
      # Allow HTTPS to external services
      to {}
      ports {
        port     = "443"
        protocol = "TCP"
      }
    }

    egress {
      # Allow HTTP for package downloads
      to {}
      ports {
        port     = "80"
        protocol = "TCP"
      }
    }
  }

  depends_on = [
    kubernetes_namespace.crossplane_system
  ]
}