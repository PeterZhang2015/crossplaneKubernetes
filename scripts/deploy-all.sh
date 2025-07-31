#!/bin/bash

# Complete deployment script for Crossplane Kubernetes automation platform
# with unified GitOps architecture
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="../terraform"
ARGOCD_DIR="../argocd"
APPS_DIR="../applications"

echo -e "${BLUE}=== Crossplane Kubernetes Automation Platform Deployment ===${NC}"
echo -e "${BLUE}🚀 Unified GitOps Architecture with ArgoCD + Crossplane${NC}"
echo -e "${YELLOW}This script will deploy the complete platform including:${NC}"
echo -e "  • Management cluster with Terraform"
echo -e "  • ArgoCD for unified GitOps control"
echo -e "  • Crossplane with AWS providers (via ArgoCD)"
echo -e "  • Worker cluster infrastructure (via ArgoCD)"
echo -e "  • Test applications (via ArgoCD)"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if required tools are installed
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Error: terraform is required but not installed.${NC}" >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}Error: kubectl is required but not installed.${NC}" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}Error: aws CLI is required but not installed.${NC}" >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo -e "${RED}Error: helm is required but not installed.${NC}" >&2; exit 1; }

# Check AWS credentials
if ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${RED}Error: AWS credentials not configured or invalid.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"

# Step 1: Deploy Management Cluster
echo -e "${BLUE}Step 1: Deploying Management Cluster with Terraform${NC}"
cd "$TERRAFORM_DIR"

if [ ! -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}Creating terraform.tfvars from example...${NC}"
    cp terraform.tfvars.example terraform.tfvars
    echo -e "${YELLOW}Please edit terraform.tfvars with your specific values and run this script again.${NC}"
    exit 1
fi

echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

echo -e "${YELLOW}Planning Terraform deployment...${NC}"
terraform plan -out=tfplan

echo -e "${YELLOW}Applying Terraform configuration...${NC}"
terraform apply tfplan

echo -e "${GREEN}✓ Management cluster deployed successfully${NC}"

# Step 2: Configure kubectl
echo -e "${BLUE}Step 2: Configuring kubectl${NC}"
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw aws_region || echo "us-west-2")

echo -e "${YELLOW}Updating kubeconfig for cluster: ${CLUSTER_NAME}${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# Verify cluster connection
echo -e "${YELLOW}Verifying cluster connection...${NC}"
kubectl cluster-info
kubectl get nodes

echo -e "${GREEN}✓ kubectl configured successfully${NC}"

# Step 3: Wait for Crossplane to be ready
echo -e "${BLUE}Step 3: Waiting for Crossplane to be ready${NC}"
echo -e "${YELLOW}Waiting for Crossplane pods to be ready...${NC}"
kubectl wait --for=condition=Ready pods --all -n crossplane-system --timeout=600s

echo -e "${YELLOW}Checking Crossplane providers...${NC}"
kubectl get providers

echo -e "${GREEN}✓ Crossplane is ready${NC}"

# Step 4: Deploy GitOps Infrastructure
echo -e "${BLUE}Step 4: Deploying GitOps Infrastructure${NC}"
cd "../$ARGOCD_DIR"

echo -e "${YELLOW}Deploying ArgoCD configurations...${NC}"
./scripts/deploy-argocd-configs.sh

echo -e "${YELLOW}Applying infrastructure applications...${NC}"
kubectl apply -f infrastructure/

echo -e "${YELLOW}Waiting for infrastructure applications to sync...${NC}"
sleep 30

# Monitor ArgoCD applications
echo -e "${YELLOW}Checking ArgoCD application status...${NC}"
kubectl get applications -n argocd

echo -e "${GREEN}✓ GitOps infrastructure deployed successfully${NC}"

echo -e "${GREEN}=== Deployment Completed Successfully ===${NC}"
echo -e "${YELLOW}Platform is ready for use!${NC}"
echo -e "${YELLOW}Access ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
echo -e "${YELLOW}Get ArgoCD password: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d${NC}"