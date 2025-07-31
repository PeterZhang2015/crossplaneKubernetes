# EKS Cluster Service Role
resource "aws_iam_role" "cluster_service_role" {
  name = "${var.cluster_name}-cluster-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-cluster-service-role"
    Environment = var.environment
  }
}

# Attach required policies to cluster service role
resource "aws_iam_role_policy_attachment" "cluster_service_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_service_role.name
}

# EKS Node Group Role
resource "aws_iam_role" "node_group_role" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-node-group-role"
    Environment = var.environment
  }
}

# Attach required policies to node group role
resource "aws_iam_role_policy_attachment" "node_group_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group_role.name
}

resource "aws_iam_role_policy_attachment" "node_group_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group_role.name
}

# Crossplane IRSA Role
resource "aws_iam_role" "crossplane_irsa" {
  name = "${var.cluster_name}-crossplane-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.crossplane_namespace}:crossplane"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-crossplane-irsa"
    Environment = var.environment
  }
}

# Crossplane IAM Policy
resource "aws_iam_policy" "crossplane_policy" {
  name        = "${var.cluster_name}-crossplane-policy"
  description = "IAM policy for Crossplane to manage AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EKS permissions
          "eks:*",
          # EC2 permissions for VPC and networking
          "ec2:*",
          # IAM permissions for roles and policies
          "iam:*",
          # RDS permissions
          "rds:*",
          # Secrets Manager permissions
          "secretsmanager:*",
          # CloudFormation permissions (used by some providers)
          "cloudformation:*",
          # S3 permissions for state and artifacts
          "s3:*",
          # CloudWatch permissions for monitoring
          "cloudwatch:*",
          "logs:*",
          # Route53 permissions for DNS
          "route53:*",
          # ACM permissions for certificates
          "acm:*",
          # ELB permissions for load balancers
          "elasticloadbalancing:*",
          # Auto Scaling permissions
          "autoscaling:*",
          # KMS permissions for encryption
          "kms:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-crossplane-policy"
    Environment = var.environment
  }
}

# Attach Crossplane policy to IRSA role
resource "aws_iam_role_policy_attachment" "crossplane_irsa_policy" {
  policy_arn = aws_iam_policy.crossplane_policy.arn
  role       = aws_iam_role.crossplane_irsa.name
}

# Additional IAM role for ArgoCD (to be used by worker clusters)
resource "aws_iam_role" "argocd_irsa" {
  name = "${var.cluster_name}-argocd-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-server"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-argocd-irsa"
    Environment = var.environment
  }
}

# ArgoCD IAM Policy (minimal permissions for GitOps operations)
resource "aws_iam_policy" "argocd_policy" {
  name        = "${var.cluster_name}-argocd-policy"
  description = "IAM policy for ArgoCD operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # Secrets Manager access for application secrets
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          # ECR access for container images
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          # CloudWatch for logging
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-argocd-policy"
    Environment = var.environment
  }
}

# Attach ArgoCD policy to IRSA role
resource "aws_iam_role_policy_attachment" "argocd_irsa_policy" {
  policy_arn = aws_iam_policy.argocd_policy.arn
  role       = aws_iam_role.argocd_irsa.name
}