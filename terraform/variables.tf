# General Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "crossplane-k8s-automation"
}

# EKS Configuration
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "crossplane-management-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "node_group_instance_types" {
  description = "Instance types for EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 4
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 1
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# Crossplane Configuration
variable "crossplane_namespace" {
  description = "Namespace for Crossplane installation"
  type        = string
  default     = "crossplane-system"
}

variable "crossplane_chart_version" {
  description = "Crossplane Helm chart version"
  type        = string
  default     = "1.14.5"
}

# ArgoCD Configuration
variable "argocd_namespace" {
  description = "Namespace for ArgoCD installation"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "argocd_image_tag" {
  description = "ArgoCD image tag"
  type        = string
  default     = "v2.9.3"
}

# Git Repository Configuration
variable "git_repository_url" {
  description = "Git repository URL for infrastructure configurations"
  type        = string
  default     = "https://github.com/PeterZhang2015/crossplaneKubernetes.git"
}

variable "git_repository_private" {
  description = "Whether the Git repository is private"
  type        = bool
  default     = false
}

variable "git_username" {
  description = "Git username for private repository access"
  type        = string
  default     = ""
  sensitive   = true
}

variable "git_token" {
  description = "Git token for private repository access"
  type        = string
  default     = ""
  sensitive   = true
}

# Domain Configuration
variable "domain_name" {
  description = "Domain name for ArgoCD ingress"
  type        = string
  default     = "peterzhang2015.dev"
}

# OIDC Configuration
variable "oidc_enabled" {
  description = "Enable OIDC authentication for ArgoCD"
  type        = bool
  default     = false
}

variable "oidc_client_secret" {
  description = "OIDC client secret"
  type        = string
  default     = ""
  sensitive   = true
}

# Notification Configuration
variable "slack_token" {
  description = "Slack token for ArgoCD notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}