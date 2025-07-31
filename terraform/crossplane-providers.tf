# AWS Provider for Crossplane
resource "kubernetes_manifest" "aws_provider" {
  manifest = {
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Provider"
    metadata = {
      name = "provider-aws"
      namespace = kubernetes_namespace.crossplane_system.metadata[0].name
    }
    spec = {
      package = "xpkg.upbound.io/crossplane-contrib/provider-aws:v0.44.0"
      packagePullPolicy = "IfNotPresent"
      revisionActivationPolicy = "Automatic"
      revisionHistoryLimit = 3
    }
  }

  depends_on = [
    time_sleep.wait_for_crossplane
  ]
}

# Helm Provider for Crossplane (for ArgoCD installation)
resource "kubernetes_manifest" "helm_provider" {
  manifest = {
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Provider"
    metadata = {
      name = "provider-helm"
      namespace = kubernetes_namespace.crossplane_system.metadata[0].name
    }
    spec = {
      package = "xpkg.upbound.io/crossplane-contrib/provider-helm:v0.15.0"
      packagePullPolicy = "IfNotPresent"
      revisionActivationPolicy = "Automatic"
      revisionHistoryLimit = 3
    }
  }

  depends_on = [
    time_sleep.wait_for_crossplane
  ]
}

# Kubernetes Provider for Crossplane
resource "kubernetes_manifest" "kubernetes_provider" {
  manifest = {
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Provider"
    metadata = {
      name = "provider-kubernetes"
      namespace = kubernetes_namespace.crossplane_system.metadata[0].name
    }
    spec = {
      package = "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.11.0"
      packagePullPolicy = "IfNotPresent"
      revisionActivationPolicy = "Automatic"
      revisionHistoryLimit = 3
    }
  }

  depends_on = [
    time_sleep.wait_for_crossplane
  ]
}

# Wait for providers to be installed
resource "time_sleep" "wait_for_providers" {
  depends_on = [
    kubernetes_manifest.aws_provider,
    kubernetes_manifest.helm_provider,
    kubernetes_manifest.kubernetes_provider
  ]
  create_duration = "120s"
}

# AWS ProviderConfig
resource "kubernetes_manifest" "aws_provider_config" {
  manifest = {
    apiVersion = "aws.crossplane.io/v1beta1"
    kind       = "ProviderConfig"
    metadata = {
      name = "default"
    }
    spec = {
      credentials = {
        source = "InjectedIdentity"
      }
      region = var.aws_region
    }
  }

  depends_on = [
    time_sleep.wait_for_providers,
    kubernetes_service_account.crossplane
  ]
}

# Helm ProviderConfig for worker clusters
resource "kubernetes_manifest" "helm_provider_config" {
  manifest = {
    apiVersion = "helm.crossplane.io/v1beta1"
    kind       = "ProviderConfig"
    metadata = {
      name = "default"
    }
    spec = {
      credentials = {
        source = "InjectedIdentity"
      }
    }
  }

  depends_on = [
    time_sleep.wait_for_providers
  ]
}

# Kubernetes ProviderConfig for worker clusters
resource "kubernetes_manifest" "kubernetes_provider_config" {
  manifest = {
    apiVersion = "kubernetes.crossplane.io/v1alpha1"
    kind       = "ProviderConfig"
    metadata = {
      name = "default"
    }
    spec = {
      credentials = {
        source = "InjectedIdentity"
      }
    }
  }

  depends_on = [
    time_sleep.wait_for_providers
  ]
}

# Service Account for AWS Provider
resource "kubernetes_service_account" "aws_provider" {
  metadata {
    name      = "provider-aws"
    namespace = kubernetes_namespace.crossplane_system.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.crossplane_irsa.arn
    }
    
    labels = {
      "app.kubernetes.io/name" = "provider-aws"
      "app.kubernetes.io/component" = "crossplane-provider"
    }
  }

  depends_on = [
    kubernetes_manifest.aws_provider,
    aws_iam_role.crossplane_irsa
  ]
}

# ClusterRoleBinding for AWS Provider
resource "kubernetes_cluster_role_binding" "aws_provider" {
  metadata {
    name = "provider-aws"
    
    labels = {
      "app.kubernetes.io/name" = "provider-aws"
      "app.kubernetes.io/component" = "crossplane-provider"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "crossplane:provider:provider-aws"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aws_provider.metadata[0].name
    namespace = kubernetes_service_account.aws_provider.metadata[0].namespace
  }

  depends_on = [
    kubernetes_service_account.aws_provider,
    time_sleep.wait_for_providers
  ]
}

# Service Account for Helm Provider
resource "kubernetes_service_account" "helm_provider" {
  metadata {
    name      = "provider-helm"
    namespace = kubernetes_namespace.crossplane_system.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.crossplane_irsa.arn
    }
    
    labels = {
      "app.kubernetes.io/name" = "provider-helm"
      "app.kubernetes.io/component" = "crossplane-provider"
    }
  }

  depends_on = [
    kubernetes_manifest.helm_provider,
    aws_iam_role.crossplane_irsa
  ]
}

# Service Account for Kubernetes Provider
resource "kubernetes_service_account" "kubernetes_provider" {
  metadata {
    name      = "provider-kubernetes"
    namespace = kubernetes_namespace.crossplane_system.metadata[0].name
    
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.crossplane_irsa.arn
    }
    
    labels = {
      "app.kubernetes.io/name" = "provider-kubernetes"
      "app.kubernetes.io/component" = "crossplane-provider"
    }
  }

  depends_on = [
    kubernetes_manifest.kubernetes_provider,
    aws_iam_role.crossplane_irsa
  ]
}