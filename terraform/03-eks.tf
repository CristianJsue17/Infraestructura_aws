# ====================================
# AMAZON EKS - ELASTIC KUBERNETES SERVICE
# ====================================

# ====================================
# IAM ROLE - EKS CLUSTER
# ====================================

resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

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
    Name        = "${var.project_name}-eks-cluster-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ====================================
# SECURITY GROUP - EKS CLUSTER
# ====================================

resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.project_name}-eks-cluster-"
  description = "Security group for EKS cluster control plane"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-eks-cluster-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ====================================
# SECURITY GROUP - EKS NODES
# ====================================

resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-eks-nodes-"
  description = "Security group for EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                                    = "${var.project_name}-eks-nodes-sg"
    Environment                                             = var.environment
    "kubernetes.io/cluster/${var.project_name}-eks-cluster" = "owned"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ====================================
# SECURITY GROUP RULES - EKS CLUSTER (SEPARADAS)
# ====================================

resource "aws_security_group_rule" "cluster_ingress_bastion" {
  description              = "Allow Bastion to access EKS API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "cluster_ingress_nodes" {
  description              = "Allow nodes to communicate with cluster API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

# ====================================
# SECURITY GROUP RULES - EKS NODES (SEPARADAS)
# ====================================

resource "aws_security_group_rule" "nodes_ingress_self" {
  description       = "Allow nodes to communicate with each other"
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.eks_nodes.id
  self              = true
}

resource "aws_security_group_rule" "nodes_ingress_cluster" {
  description              = "Allow cluster to communicate with nodes"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.eks_cluster.id
}

resource "aws_security_group_rule" "nodes_ingress_nlb" {
  description       = "Allow NLB health checks and traffic"
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = [var.vpc_cidr]
}

# ====================================
# EKS CLUSTER
# ====================================

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.eks_cluster_version

  vpc_config {
    subnet_ids              = concat(module.vpc.private_subnets, module.vpc.public_subnets)
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = {
    Name        = "${var.project_name}-eks-cluster"
    Environment = var.environment
  }
}

# ====================================
# CLOUDWATCH LOG GROUP - EKS
# ====================================

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.project_name}-eks-cluster/cluster"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-eks-logs"
    Environment = var.environment
  }
}

# ====================================
# IAM ROLE - EKS NODE GROUP
# ====================================

resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-eks-node-group-role"

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
    Name        = "${var.project_name}-eks-node-group-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy" "eks_nodes_secrets_manager" {
  name = "${var.project_name}-eks-nodes-secrets-manager"
  role = aws_iam_role.eks_nodes.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-*"
        ]
      }
    ]
  })
}

# ====================================
# EKS NODE GROUP
# ====================================

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = module.vpc.private_subnets

  scaling_config {
    desired_size = var.eks_node_desired_size
    max_size     = var.eks_node_max_size
    min_size     = var.eks_node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = [var.eks_node_instance_type]
  capacity_type  = "ON_DEMAND"
  disk_size      = var.eks_node_disk_size

  labels = {
    Environment = var.environment
    Project     = var.project_name
  }

  tags = {
    Name        = "${var.project_name}-node-group"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]
}

# ====================================
# EKS ADDONS
# ====================================

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.main]

  tags = {
    Name        = "${var.project_name}-coredns-addon"
    Environment = var.environment
  }
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  depends_on = [aws_eks_node_group.main]

  tags = {
    Name        = "${var.project_name}-kube-proxy-addon"
    Environment = var.environment
  }
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  depends_on = [aws_eks_node_group.main]

  tags = {
    Name        = "${var.project_name}-vpc-cni-addon"
    Environment = var.environment
  }
}

# ====================================
# OIDC PROVIDER
# ====================================

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name        = "${var.project_name}-eks-oidc"
    Environment = var.environment
  }
}











# ====================================
# SECURITY GROUP RULE - BASTION TO NODEPORTS
# ====================================

# YA EXISTE - NO AGREGAR
# resource "aws_security_group_rule" "nodes_ingress_bastion_nodeports" {
#   description              = "Allow Bastion to access NodePorts"
#   from_port                = 30000
#   to_port                  = 32767
#   protocol                 = "tcp"
#   security_group_id        = aws_security_group.eks_nodes.id
#   source_security_group_id = aws_security_group.bastion.id
#   type                     = "ingress"
# }

# ====================================
# SECURITY GROUP RULE - NLB ESPECÍFICO
# ====================================

resource "aws_security_group_rule" "nodes_ingress_nlb_auth" {
  description       = "Allow NLB to access autenticacion NodePort"
  type              = "ingress"
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = [var.vpc_cidr]
}

resource "aws_security_group_rule" "nodes_ingress_nlb_productos" {
  description       = "Allow NLB to access productos NodePort"
  type              = "ingress"
  from_port         = 30081
  to_port           = 30081
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_nodes.id
  cidr_blocks       = [var.vpc_cidr]
}






# ====================================
# SECURITY GROUP RULE - BASTION TO SPECIFIC NODEPORTS
# ====================================

resource "aws_security_group_rule" "nodes_ingress_bastion_auth" {
  description              = "Allow Bastion to access autenticacion NodePort"
  type                     = "ingress"
  from_port                = 30080
  to_port                  = 30080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "nodes_ingress_bastion_productos" {
  description              = "Allow Bastion to access productos NodePort"
  type                     = "ingress"
  from_port                = 30081
  to_port                  = 30081
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.bastion.id
}







# Permitir tráfico del Bastion a los pods
resource "aws_security_group_rule" "nodes_ingress_bastion_all" {
  description              = "Allow Bastion to access all pod traffic"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.bastion.id
}


