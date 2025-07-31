# Crossplane Kubernetes Automation Platform - Deployment Guide

This guide provides step-by-step instructions for deploying the complete Crossplane Kubernetes automation platform with **unified GitOps architecture**.

## Overview

The platform consists of:
- **Management Cluster**: EKS cluster with ArgoCD and Crossplane for unified GitOps control
- **Worker Clusters**: Declaratively created EKS clusters managed by ArgoCD
- **Applications**: Deployed across worker clusters via GitOps
- **Database**: AWS RDS PostgreSQL instances for application data

## Key Innovation: Unified GitOps Control

**ArgoCD in the management cluster manages everything:**
- 🏗️ **Infrastructure**: Crossplane XRDs, Compositions, and Claims
- 🚀 **Worker Clusters**: EKS clusters, RDS databases, networking
- 📱 **Applications**: Deployed to multiple worker clusters
- 🔧 **Platform Services**: Monitoring, logging, security

## Prerequisites

### Required Tools
- [Terraform](https://terraform.io) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0
- [Helm](https://helm.sh) >= 3.0
- [Git](https://git-scm.com)

### AWS Requirements
- AWS account with appropriate permissions
- AWS CLI configured with credentials
- Sufficient service quotas for EKS, RDS, and VPC resources

### Permissions Required
The AWS user/role needs permissions for:
- EKS cluster creation and management
- VPC and networking resources
- IAM roles and policies
- RDS instances
- KMS keys
- CloudWatch logs
- Route53 (optional, for DNS)

## Quick Start

### 1. Bootstrap Management Cluster
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values
terraform init
terraform apply
```

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --region <your-region> --name crossplane-management-cluster
```

### 3. Deploy GitOps Infrastructure
```bash
# Deploy ArgoCD configurations
cd ../argocd
./scripts/deploy-argocd-configs.sh

# Apply infrastructure applications
kubectl apply -f infrastructure/
```

### 4. Monitor Infrastructure Deployment
```bash
# Watch ArgoCD applications
kubectl get applications -n argocd -w

# Monitor worker cluster creation
kubectl get workerclusters -w

# Check Crossplane status
kubectl get crossplane
```

### 5. Access ArgoCD UI
```bash
# Get ArgoCD URL and credentials
echo "ArgoCD URL: https://$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Admin Password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
```

## Manual Deployment Steps

If you prefer to deploy manually or need to troubleshoot:

### Step 1: Deploy Management Cluster

```bash
cd terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply
```

### Step 2: Configure kubectl

```bash
# Get cluster details from Terraform outputs
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw aws_region)

# Update kubeconfig
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify connection
kubectl get nodes
kubectl get pods -A
```

### Step 3: Verify Crossplane Installation

```bash
# Check Crossplane pods
kubectl get pods -n crossplane-system

# Verify providers
kubectl get providers

# Check provider configs
kubectl get providerconfigs
```

### Step 4: Deploy GitOps Infrastructure

```bash
cd ../argocd

# Deploy ArgoCD configurations
./scripts/deploy-argocd-configs.sh

# Apply infrastructure applications
kubectl apply -f infrastructure/crossplane-xrds.yaml
kubectl apply -f infrastructure/worker-clusters.yaml

# Verify infrastructure applications
kubectl get applications -n argocd
```

### Step 5: Monitor Infrastructure Deployment

```bash
# Watch ArgoCD sync infrastructure
kubectl get applications -n argocd -w

# Monitor Crossplane resource creation
kubectl get workerclusters -w
kubectl get databases -w

# Check detailed status
kubectl describe workerclusters dev-cluster
```

### Step 6: Access Worker Cluster

```bash
# Get worker cluster name
WORKER_CLUSTER_NAME=$(kubectl get workerclusters dev-cluster -o jsonpath='{.spec.cluster.name}')

# Update kubeconfig for worker cluster
aws eks update-kubeconfig --region $AWS_REGION --name $WORKER_CLUSTER_NAME --alias worker-cluster

# Switch to worker cluster
kubectl config use-context worker-cluster

# Verify worker cluster
kubectl get nodes
kubectl get pods -A
```

### Step 7: Deploy Test Application

```bash
cd ../applications

# Apply application manifests
kubectl apply -f k8s-manifests/

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n test-app --timeout=300s

# Check application status
kubectl get pods -n test-app
kubectl get services -n test-app
kubectl get ingress -n test-app
```

## Accessing Services

### ArgoCD
```bash
# Get ArgoCD URL
kubectl get ingress -n argocd argocd-server

# Get admin password
kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

### Test Application
```bash
# Get application URL
kubectl get ingress -n test-app test-app-ingress

# Test API endpoints
curl https://<app-url>/api/health
curl https://<app-url>/api/tasks
```

### Database Connection
```bash
# Get database connection details
kubectl get secret -n test-app database-connection -o yaml

# Connect to database (decode base64 values first)
psql "postgresql://username:password@endpoint:5432/database"
```

## Environment Management

### Deploy Staging Environment
```bash
kubectl apply -f claims/staging-cluster-claim.yaml
```

### Deploy Production Environment
```bash
kubectl apply -f claims/prod-cluster-claim.yaml
```

### Switch Between Environments
```bash
# List available contexts
kubectl config get-contexts

# Switch to specific cluster
kubectl config use-context <context-name>
```

## Monitoring and Troubleshooting

### Check Crossplane Status
```bash
# Overall Crossplane health
kubectl get crossplane

# Provider status
kubectl get providers
kubectl describe provider provider-aws

# Managed resources
kubectl get managed

# Composite resources
kubectl get composite
```

### Check Worker Cluster Status
```bash
# Cluster status
kubectl get workerclusters
kubectl describe workerclusters <cluster-name>

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Application Troubleshooting
```bash
# Check pod status
kubectl get pods -n test-app
kubectl describe pod <pod-name> -n test-app

# Check logs
kubectl logs -f deployment/backend -n test-app
kubectl logs -f deployment/frontend -n test-app

# Check services and ingress
kubectl get svc,ingress -n test-app
```

### ArgoCD Troubleshooting
```bash
# Check ArgoCD applications
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd

# ArgoCD server logs
kubectl logs -f deployment/argocd-server -n argocd
```

## Cleanup

### Remove Test Application
```bash
kubectl delete -f applications/k8s-manifests/
```

### Remove Worker Clusters
```bash
kubectl delete -f crossplane/claims/dev-cluster-claim.yaml
kubectl delete -f crossplane/claims/staging-cluster-claim.yaml
kubectl delete -f crossplane/claims/prod-cluster-claim.yaml
```

### Remove Crossplane Configurations
```bash
kubectl delete -f crossplane/compositions/
kubectl delete -f crossplane/xrd-worker-cluster.yaml
kubectl delete -f crossplane/xrd-database.yaml
```

### Destroy Management Cluster
```bash
cd terraform
terraform destroy
```

## Security Considerations

### Network Security
- Private subnets for worker nodes
- Security groups with minimal required access
- VPC endpoints for AWS services
- Network policies for pod-to-pod communication

### Identity and Access Management
- IAM roles for service accounts (IRSA)
- Least privilege principle
- Regular access reviews
- Multi-factor authentication for human access

### Data Protection
- Encryption at rest for all data stores
- Encryption in transit using TLS
- Secrets management with AWS Secrets Manager
- Regular backup and recovery testing

### Compliance
- Pod Security Standards enforcement
- Resource quotas and limits
- Audit logging enabled
- Compliance scanning with tools like Falco

## Best Practices

### Resource Management
- Set appropriate resource requests and limits
- Use horizontal pod autoscaling
- Implement cluster autoscaling
- Monitor resource usage

### High Availability
- Multi-AZ deployments
- Pod disruption budgets
- Health checks and probes
- Graceful shutdown handling

### Monitoring and Alerting
- Prometheus for metrics collection
- Grafana for visualization
- AlertManager for notifications
- Centralized logging with ELK stack

### GitOps Workflow
- All configuration in Git
- Automated testing and validation
- Environment promotion pipelines
- Rollback capabilities

## Support and Documentation

### Useful Commands
```bash
# Get cluster information
kubectl cluster-info

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Debug networking
kubectl run debug --image=nicolaka/netshoot -it --rm

# Port forwarding for local access
kubectl port-forward svc/backend 8000:80 -n test-app
```

### Additional Resources
- [Crossplane Documentation](https://crossplane.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

### Getting Help
- Check logs and events for error messages
- Use `kubectl describe` for detailed resource information
- Review AWS CloudTrail for API call history
- Consult the troubleshooting section above