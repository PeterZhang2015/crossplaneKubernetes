# EKS Cluster Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# IAM Outputs
output "crossplane_irsa_role_arn" {
  description = "ARN of the IAM role for Crossplane IRSA"
  value       = aws_iam_role.crossplane_irsa.arn
}

output "argocd_irsa_role_arn" {
  description = "ARN of the IAM role for ArgoCD IRSA"
  value       = aws_iam_role.argocd_irsa.arn
}

output "node_group_role_arn" {
  description = "ARN of the IAM role for EKS node groups"
  value       = aws_iam_role.node_group_role.arn
}

# OIDC Provider
output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC Provider"
  value       = module.eks.cluster_oidc_issuer_url
}

# KMS Key
output "eks_kms_key_arn" {
  description = "ARN of the KMS key used for EKS encryption"
  value       = aws_kms_key.eks.arn
}

# Security Groups
output "cluster_security_group_id" {
  description = "Security group ID for the EKS cluster"
  value       = aws_security_group.cluster_security_group.id
}

output "node_security_group_id" {
  description = "Security group ID for the EKS node groups"
  value       = aws_security_group.node_group_security_group.id
}

# Kubeconfig command
output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Connection script
output "connect_script" {
  description = "Script to connect to the cluster"
  value = <<-EOT
    #!/bin/bash
    echo "Updating kubeconfig..."
    aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
    echo "Verifying connection..."
    kubectl get nodes
    kubectl get pods -A
    echo "Cluster connection successful!"
  EOT
}

# ArgoCD Outputs
output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_server_service" {
  description = "ArgoCD server service name"
  value       = "argocd-server"
}

output "argocd_admin_password_command" {
  description = "Command to get ArgoCD admin password"
  value       = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_port_forward_command" {
  description = "Command to port-forward to ArgoCD server"
  value       = "kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:443"
}

output "argocd_access_info" {
  description = "Information on how to access ArgoCD"
  value = <<-EOT
    ArgoCD Access Information:
    
    1. Get admin password:
       kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
    
    2. Port forward to access UI:
       kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:443
    
    3. Access ArgoCD UI:
       https://localhost:8080
       Username: admin
       Password: (from step 1)
    
    4. Or get LoadBalancer URL (if using LoadBalancer service):
       kubectl get svc argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name}
  EOT
}

# Crossplane Outputs
output "crossplane_namespace" {
  description = "Namespace where Crossplane is installed"
  value       = kubernetes_namespace.crossplane_system.metadata[0].name
}

output "crossplane_status_command" {
  description = "Command to check Crossplane status"
  value       = "kubectl get pods -n ${kubernetes_namespace.crossplane_system.metadata[0].name}"
}

# Setup Commands
output "setup_commands" {
  description = "Commands to set up and verify the platform"
  value = <<-EOT
    Platform Setup Commands:
    
    1. Update kubeconfig:
       aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}
    
    2. Verify cluster:
       kubectl get nodes
       kubectl get pods -A
    
    3. Check Crossplane:
       kubectl get pods -n ${kubernetes_namespace.crossplane_system.metadata[0].name}
       kubectl get providers
    
    4. Check ArgoCD:
       kubectl get pods -n ${kubernetes_namespace.argocd.metadata[0].name}
    
    5. Get ArgoCD admin password:
       kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
    
    6. Access ArgoCD UI:
       kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:443
       Then open: https://localhost:8080
  EOT
}