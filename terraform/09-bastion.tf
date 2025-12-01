# ====================================
# BASTION HOST - Con acceso a EKS (kubectl)
# ====================================

# ====================================
# SECURITY GROUP - BASTION
# ====================================

resource "aws_security_group" "bastion" {
  name_prefix = "${var.project_name}-bastion-"
  description = "Security group para Bastion Host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-bastion-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ====================================
# IAM ROLE - BASTION
# ====================================

resource "aws_iam_role" "bastion" {
  name = "${var.project_name}-bastion-role"

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
    Name        = "${var.project_name}-bastion-role"
    Environment = var.environment
  }
}

# Política para SSM Session Manager
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Política para CloudWatch Logs
resource "aws_iam_role_policy_attachment" "bastion_cloudwatch" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Política personalizada para acceso a EKS
resource "aws_iam_role_policy" "bastion_eks_access" {
  name = "${var.project_name}-bastion-eks-access"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:Connect"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance Profile
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Name        = "${var.project_name}-bastion-profile"
    Environment = var.environment
  }
}

# ====================================
# ELASTIC IP - BASTION
# ====================================

resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-bastion-eip"
    Environment = var.environment
  }
}

resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}

# ====================================
# DATA SOURCE - AMI
# ====================================

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ====================================
# USER DATA - BASTION
# ====================================

locals {
  bastion_user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Actualizar sistema
    yum update -y
    
    # Instalar herramientas básicas
    yum install -y \
      git \
      curl \
      wget \
      vim \
      htop \
      postgresql15 \
      jq
    
    # Instalar AWS CLI v2
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws
    
    # Instalar kubectl
    curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    
    # Instalar helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    # Configurar kubectl para EKS
    aws eks update-kubeconfig \
      --name ${aws_eks_cluster.main.name} \
      --region ${var.aws_region}
    
    # Copiar configuración para ec2-user
    mkdir -p /home/ec2-user/.kube
    cp /root/.kube/config /home/ec2-user/.kube/config
    chown -R ec2-user:ec2-user /home/ec2-user/.kube
    
    # Configurar aliases útiles
    cat >> /home/ec2-user/.bashrc <<'ALIASES'
    
    # Aliases para kubectl
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgd='kubectl get deployments'
    alias kgn='kubectl get nodes'
    alias kdp='kubectl describe pod'
    alias kds='kubectl describe service'
    alias kdd='kubectl describe deployment'
    alias kl='kubectl logs'
    alias klf='kubectl logs -f'
    alias kex='kubectl exec -it'
    
    # Aliases para AWS
    alias eks-nodes='aws eks describe-nodegroup --cluster-name ${aws_eks_cluster.main.name} --nodegroup-name ${aws_eks_node_group.main.node_group_name} --region ${var.aws_region}'
    alias rds-auth='aws rds describe-db-instances --db-instance-identifier ${aws_db_instance.autenticacion.identifier} --region ${var.aws_region}'
    alias rds-prod='aws rds describe-db-instances --db-instance-identifier ${aws_db_instance.productos.identifier} --region ${var.aws_region}'
    
    # Configuración de kubectl namespace por defecto
    kubectl config set-context --current --namespace=${var.project_name}
    
    # Mostrar info del cluster
    echo "========================================="
    echo "BASTION HOST CONFIGURADO"
    echo "========================================="
    echo "EKS Cluster: ${aws_eks_cluster.main.name}"
    echo "Namespace: ${var.project_name}"
    echo "========================================="
    ALIASES
    
    # Banner de bienvenida
    cat > /etc/motd <<'MOTD'
    ╔══════════════════════════════════════════════════════════════╗
    ║              BASTION HOST - EKS MICROSERVICIOS               ║
    ╚══════════════════════════════════════════════════════════════╝
    
    Comandos útiles:
    
    📦 KUBERNETES:
      k get pods              - Listar pods
      k get services          - Listar servicios
      k get deployments       - Listar deployments
      k logs <pod>            - Ver logs de un pod
      k exec -it <pod> bash   - Conectar a un pod
    
    ☁️  AWS:
      eks-nodes               - Info de nodos EKS
      rds-auth                - Info de RDS autenticación
      rds-prod                - Info de RDS productos
    
    🔍 MONITOREO:
      kubectl top nodes       - Uso de recursos en nodos
      kubectl top pods        - Uso de recursos en pods
    
    🗄️  BASE DE DATOS:
      psql -h <RDS_ENDPOINT> -U dbadmin -d autenticacion_db
      psql -h <RDS_ENDPOINT> -U dbadmin -d productos_db
    
    ╚══════════════════════════════════════════════════════════════╝
    MOTD
    
    # Completar instalación
    echo "Bastion configurado correctamente" > /tmp/bastion-setup-complete
  EOF
}

# ====================================
# EC2 INSTANCE - BASTION
# ====================================

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.bastion_instance_type
  key_name               = var.bastion_key_name
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  user_data = base64encode(local.bastion_user_data)

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.project_name}-bastion"
    Environment = var.environment
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]
}

# ====================================
# AWS AUTH CONFIGMAP
# ====================================

# NOTA: El ConfigMap aws-auth debe configurarse manualmente desde el Bastion
# después del despliegue con:
# kubectl edit configmap aws-auth -n kube-system

# ====================================
# SECURITY GROUP RULES - BASTION → EKS NODES
# ====================================

# Permitir que el Bastion acceda a los NodePorts de EKS
resource "aws_security_group_rule" "bastion_to_eks_nodeports" {
  type                     = "egress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Allow Bastion to access EKS NodePorts"
}

resource "aws_security_group_rule" "eks_nodes_from_bastion" {
  type                     = "ingress"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.bastion.id
  description              = "Allow Bastion to access NodePorts"
}





# Regla de EGRESS para que el Bastion pueda acceder a los pods
resource "aws_security_group_rule" "bastion_to_pod_cidr" {
  description       = "Allow Bastion to access pod network"
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  security_group_id = aws_security_group.bastion.id
  cidr_blocks       = ["10.0.0.0/16"]  # Toda la VPC
}