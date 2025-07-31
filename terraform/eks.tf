# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  # Cluster security group
  cluster_security_group_id = aws_security_group.cluster_security_group.id

  # Enable cluster logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Encryption configuration
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    main = {
      name = "${var.cluster_name}-main-ng"

      instance_types = var.node_group_instance_types
      
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Use custom launch template for additional security
      create_launch_template = true
      launch_template_name   = "${var.cluster_name}-main-ng-lt"

      # Node group configuration
      ami_type       = "AL2_x86_64"
      capacity_type  = "ON_DEMAND"
      disk_size      = 50
      
      # Security groups
      vpc_security_group_ids = [aws_security_group.node_group_security_group.id]

      # IAM role
      iam_role_arn = aws_iam_role.node_group_role.arn

      # User data for additional security hardening
      user_data = base64encode(templatefile("${path.module}/user_data.sh", {
        cluster_name = var.cluster_name
        region       = var.aws_region
      }))

      # Labels and taints
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      # Update configuration
      update_config = {
        max_unavailable_percentage = 25
      }

      tags = {
        Name = "${var.cluster_name}-main-ng"
        Environment = var.environment
      }
    }
  }

  # Cluster access entries (replaces aws-auth ConfigMap)
  access_entries = {
    admin = {
      kubernetes_groups = []
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = {
    Name = var.cluster_name
    Environment = var.environment
    Project = var.project_name
  }
}

# KMS Key for EKS encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key for ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.cluster_name}-eks-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# CloudWatch Log Group for EKS cluster logs
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 30

  tags = {
    Name = "${var.cluster_name}-cluster-logs"
    Environment = var.environment
  }
}