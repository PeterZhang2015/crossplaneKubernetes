# Crossplane Kubernetes Automation with Unified GitOps

This project implements a fully automated Kubernetes platform using **Terraform** for bootstrapping, **Crossplane** for infrastructure provisioning, and **ArgoCD** for unified GitOps control of both infrastructure and applications.

## Key Innovation: Unified GitOps Architecture

**ArgoCD in the management cluster manages everything:**
- 🏗️ **Infrastructure**: Crossplane XRDs, Compositions, and Claims
- 🚀 **Worker Clusters**: EKS clusters, RDS databases, networking
- 📱 **Applications**: Deployed across multiple worker clusters
- 🔧 **Platform Services**: Monitoring, logging, security

## Architecture Overview

- **Management Cluster**: EKS cluster with ArgoCD and Crossplane for unified GitOps control
- **Worker Clusters**: Declaratively created by Crossplane, managed by ArgoCD for application deployment
- **Database**: AWS RDS provisioned by Crossplane for application data persistence
- **GitOps Workflow**: ArgoCD manages both infrastructure (via Crossplane) and applications

### GitOps Architecture

```
Management Cluster                    Worker Clusters
├── ArgoCD (GitOps Controller)       ├── ArgoCD (Application Controller)
├── Crossplane (Infrastructure)      ├── Applications (via GitOps)
└── Terraform (Bootstrap)            └── Monitoring & Logging
         │                                    ▲
         ▼                                    │
    AWS Resources                    Managed by Management ArgoCD
    ├── EKS Clusters
    ├── RDS Databases
    └── VPC/Networking
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Helm >= 3.0
- Git

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
# Deploy ArgoCD configurations for infrastructure management
cd ../argocd
./scripts/deploy-argocd-configs.sh

# Apply infrastructure applications (XRDs, Compositions, Claims)
kubectl apply -f infrastructure/
```

### 4. Verify Infrastructure Deployment
```bash
# Check Crossplane status
kubectl get crossplane
kubectl get providers

# Check ArgoCD applications
kubectl get applications -n argocd

# Monitor worker cluster creation
kubectl get workerclusters -w
```

### 5. Access ArgoCD UI
```bash
# Get ArgoCD URL and admin password
echo "ArgoCD URL: https://$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Admin Password: $(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)"
```

## Directory Structure

```
├── terraform/              # Management cluster bootstrap (Terraform + ArgoCD + Crossplane)
│   ├── main.tf             # Main Terraform configuration
│   ├── variables.tf        # Variable definitions
│   ├── outputs.tf          # Output definitions
│   ├── eks.tf              # EKS cluster configuration
│   ├── iam.tf              # IAM roles and policies
│   ├── vpc.tf              # VPC and networking
│   └── crossplane.tf       # Crossplane installation
├── crossplane/             # Crossplane configurations (managed by ArgoCD)
│   ├── compositions/       # Reusable infrastructure patterns
│   ├── claims/             # Environment-specific infrastructure requests
│   ├── xrd-worker-cluster.yaml  # Worker cluster XRD
│   └── xrd-database.yaml   # Database XRD
├── argocd/                 # ArgoCD configurations for unified GitOps
│   ├── infrastructure/     # 🆕 Infrastructure applications (XRDs, Claims)
│   ├── applications/       # Application definitions per environment
│   ├── applicationsets/    # Multi-environment ApplicationSets
│   ├── projects/           # RBAC projects (infrastructure, dev, staging, prod)
│   ├── config/             # ArgoCD server configuration
│   ├── rbac/               # Role-based access control
│   ├── notifications/      # Notification configurations
│   ├── monitoring/         # Prometheus monitoring and alerting
│   ├── examples/           # Example configurations and workflows
│   ├── scripts/            # Operational scripts (deploy, backup, sync)
│   └── GITOPS-ARCHITECTURE.md  # 🆕 Complete GitOps architecture guide
├── applications/           # Sample applications
│   ├── backend/            # FastAPI backend service
│   ├── frontend/           # React frontend application
│   └── k8s-manifests/      # Kubernetes manifests
├── scripts/                # Deployment and utility scripts
│   ├── deploy-all.sh       # Complete platform deployment
│   ├── connect-cluster.sh  # Cluster connection utilities
│   └── verify-crossplane.sh # Crossplane verification
├── README.md               # This file
└── DEPLOYMENT.md           # Comprehensive deployment guide
```

## GitOps Workflow

The platform uses a **unified GitOps approach** where ArgoCD in the management cluster orchestrates everything:

### 1. Infrastructure Management
```bash
# Update Crossplane composition
git add crossplane/compositions/worker-cluster-composition.yaml
git commit -m "Update EKS cluster composition"
git push

# ArgoCD automatically syncs changes to Crossplane
# Crossplane updates AWS infrastructure
```

### 2. Environment Provisioning
```bash
# Create new environment
git add crossplane/claims/staging-cluster-claim.yaml
git commit -m "Add staging environment"
git push

# ArgoCD creates Crossplane claim
# Crossplane provisions EKS cluster + RDS database
# ArgoCD registers new cluster and deploys applications
```

### 3. Application Deployment
```bash
# Update application
git add applications/k8s-manifests/
git commit -m "Update application to v2.0"
git push

# ArgoCD deploys to worker clusters based on environment
```

### 4. Multi-Environment Promotion
```bash
# Promote through environments
git add argocd/applications/test-app-staging.yaml
git commit -m "Promote v2.0 to staging"
git push

# Manual approval required for production
# ArgoCD UI or CLI for production sync
```

## Key Features

### 🆕 Unified GitOps Architecture
- **Single Control Plane**: ArgoCD manages both infrastructure and applications
- **Infrastructure as Code**: Crossplane resources managed via ArgoCD applications
- **Multi-Cluster Orchestration**: Centralized management of multiple worker clusters
- **Environment Promotion**: Controlled promotion from dev → staging → prod

### 🔒 Security by Default
- **RBAC Integration**: Role-based access control with OIDC/LDAP
- **IAM Roles for Service Accounts (IRSA)**: Secure AWS access
- **Encryption**: At rest and in transit for all data
- **Network Policies**: Pod-to-pod communication restrictions
- **Pod Security Standards**: Baseline and restricted policies
- **Secrets Management**: AWS Secrets Manager integration

### 📈 Comprehensive Monitoring
- **Prometheus Integration**: Metrics collection for all components
- **Grafana Dashboards**: Visual monitoring and alerting
- **ArgoCD Monitoring**: Application sync status and health
- **Infrastructure Alerts**: Crossplane resource monitoring
- **Multi-Cluster Visibility**: Unified view across all environments

### 🚀 Operational Excellence
- **Automated Deployment**: One-command platform deployment
- **Backup & Recovery**: Comprehensive backup procedures
- **Disaster Recovery**: Multi-AZ and cross-region capabilities
- **Scaling**: Horizontal and vertical scaling support
- **Maintenance Windows**: Controlled deployment timing

## Troubleshooting

### Infrastructure Issues

1. **Crossplane Resources Not Ready**
   ```bash
   # Check Crossplane provider status
   kubectl get providers
   kubectl describe provider provider-aws
   
   # Check managed resources
   kubectl get managed
   kubectl describe workerclusters dev-cluster
   ```

2. **ArgoCD Application Out of Sync**
   ```bash
   # Check application status
   kubectl get applications -n argocd
   kubectl describe application crossplane-xrds -n argocd
   
   # Manual sync if needed
   argocd app sync crossplane-xrds
   ```

3. **Worker Cluster Creation Failed**
   ```bash
   # Check Crossplane events
   kubectl get events --sort-by=.metadata.creationTimestamp
   
   # Check AWS CloudTrail for API errors
   # Verify IAM permissions for Crossplane
   ```

### Application Issues

1. **Application Deployment Failed**
   ```bash
   # Check ArgoCD application logs
   kubectl logs -f deployment/argocd-application-controller -n argocd
   
   # Check application events
   kubectl describe application test-app-dev -n argocd
   ```

2. **Database Connection Issues**
   ```bash
   # Check database status
   kubectl get databases
   kubectl describe database dev-database
   
   # Check connection secrets
   kubectl get secrets -l crossplane.io/claim-name=dev-database
   ```

### Useful Commands

```bash
# Infrastructure Management
kubectl get crossplane                    # Check Crossplane status
kubectl get providers                     # Check provider status
kubectl get workerclusters               # Check worker clusters
kubectl get databases                     # Check database status

# ArgoCD Management
kubectl get applications -n argocd       # Check all applications
kubectl get appprojects -n argocd        # Check projects
argocd app list                          # List applications (CLI)
argocd app sync <app-name>               # Sync application

# Multi-Cluster Operations
kubectl config get-contexts              # List available clusters
kubectl config use-context <context>     # Switch cluster context
kubectl get nodes --all-namespaces       # Check nodes across clusters

# Monitoring and Debugging
kubectl get events --sort-by=.metadata.creationTimestamp
kubectl logs -f deployment/argocd-application-controller -n argocd
kubectl top nodes                        # Resource usage
kubectl top pods -A                      # Pod resource usage
```

## Advanced Usage

### Custom Infrastructure

1. **Create Custom Composition**
   ```bash
   # Edit composition
   vim crossplane/compositions/custom-cluster-composition.yaml
   
   # Apply via ArgoCD
   git add crossplane/compositions/
   git commit -m "Add custom cluster composition"
   git push
   ```

2. **Add New Environment**
   ```bash
   # Create environment claim
   cp crossplane/claims/dev-cluster-claim.yaml crossplane/claims/qa-cluster-claim.yaml
   
   # Update for QA environment
   vim crossplane/claims/qa-cluster-claim.yaml
   
   # Apply via GitOps
   git add crossplane/claims/qa-cluster-claim.yaml
   git commit -m "Add QA environment"
   git push
   ```

### Multi-Cluster Applications

1. **Deploy to Multiple Clusters**
   ```bash
   # Use ApplicationSet for multi-cluster deployment
   kubectl apply -f argocd/applicationsets/infrastructure-applicationset.yaml
   ```

2. **Cross-Cluster Service Mesh**
   ```bash
   # Deploy Istio across clusters (example)
   git add applications/service-mesh/
   git commit -m "Add cross-cluster service mesh"
   git push
   ```

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)**: Comprehensive deployment guide with step-by-step instructions
- **[argocd/GITOPS-ARCHITECTURE.md](argocd/GITOPS-ARCHITECTURE.md)**: Complete GitOps architecture documentation
- **[argocd/README.md](argocd/README.md)**: ArgoCD configuration and usage guide
- **[argocd/STRUCTURE.md](argocd/STRUCTURE.md)**: Detailed ArgoCD folder structure
- **[argocd/USAGE.md](argocd/USAGE.md)**: GitOps workflow and best practices

## Related Projects

- [Crossplane](https://crossplane.io/) - Universal Control Plane
- [ArgoCD](https://argo-cd.readthedocs.io/) - Declarative GitOps CD
- [Terraform](https://terraform.io/) - Infrastructure as Code
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [External Secrets Operator](https://external-secrets.io/)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following GitOps principles
4. Add tests and documentation
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- **Infrastructure Changes**: Update Crossplane compositions and test with dev environment
- **Application Changes**: Follow the GitOps workflow for environment promotion
- **Documentation**: Update relevant documentation for any architectural changes
- **Security**: Ensure all changes follow security best practices
- **Testing**: Test changes in development environment before promoting

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: Report bugs and request features via [GitHub Issues](https://github.com/example/crossplane-k8s-automation/issues)
- **Discussions**: Join the community discussion on [GitHub Discussions](https://github.com/example/crossplane-k8s-automation/discussions)
- **Documentation**: Check the comprehensive documentation in the `docs/` folder
- **Examples**: Explore example configurations in `argocd/examples/`

## Acknowledgments

- **Crossplane Community** for the universal control plane
- **ArgoCD Community** for the GitOps continuous delivery platform
- **CNCF** for fostering cloud-native technologies
- **AWS** for the robust cloud infrastructure services
- **Kubernetes Community** for the container orchestration platform