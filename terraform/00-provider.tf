# ====================================
# PROVIDERS CONFIGURATION
# ====================================

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# ====================================
# AWS PROVIDER
# ====================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project      = var.project_name
      Environment  = var.environment
      ManagedBy    = "Terraform"
      Architecture = "EKS-Kubernetes"
      Owner        = "Estudiante"
    }
  }
}

# ====================================
# DATA SOURCES
# ====================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# ====================================
# EKS CLUSTER DATA (para Kubernetes provider)
# ====================================

data "aws_eks_cluster" "main" {
  name = aws_eks_cluster.main.name
  
  depends_on = [aws_eks_cluster.main]
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
  
  depends_on = [aws_eks_cluster.main]
}

# ====================================
# KUBERNETES PROVIDER
# ====================================

provider "kubernetes" {
  host                   = data.aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}