# ====================================
# BASTION HOST - ACCESO SEGURO
# ====================================

# AMI más reciente de Amazon Linux 2
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

# Elastic IP para Bastion
resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-bastion-eip"
    Environment = var.environment
  }
}

# IAM Role para Bastion
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

# IAM Instance Profile para Bastion
resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Name        = "${var.project_name}-bastion-profile"
    Environment = var.environment
  }
}

# Políticas para el Bastion
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "bastion_cloudwatch" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Política personalizada para acceso a ECS
resource "aws_iam_role_policy" "bastion_ecs_access" {
  name = "${var.project_name}-bastion-ecs-access"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeCluster",
          "ecs:ListClusters",
          "ecs:DescribeServices",
          "ecs:ListServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions"
        ]
        Resource = "*"
      }
    ]
  })
}

# User Data para instalar herramientas en Bastion
locals {
  bastion_user_data = <<-EOF
    #!/bin/bash
    set -e
    
    # Actualizar el sistema
    yum update -y
    
    # Instalar herramientas básicas
    yum install -y git wget curl unzip jq vim nano htop
    
    # Instalar AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    
    # Instalar PostgreSQL client
    amazon-linux-extras install postgresql14 -y
    
    # Instalar Docker (opcional)
    yum install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
    
    # Instalar AWS ECS CLI
    curl -Lo /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest
    chmod +x /usr/local/bin/ecs-cli
    
    # Crear script de bienvenida
    cat > /etc/motd << 'MOTD'
    ╔═══════════════════════════════════════════════════════════╗
    ║                                                           ║
    ║        🚀 BASTION HOST - ECS FARGATE MICROSERVICES 🚀    ║
    ║                                                           ║
    ║  Herramientas instaladas:                                ║
    ║    • AWS CLI v2                                          ║
    ║    • ECS CLI                                             ║
    ║    • PostgreSQL client                                   ║
    ║    • Docker                                              ║
    ║                                                           ║
    ║  Comandos útiles:                                        ║
    ║    aws ecs list-clusters                                 ║
    ║    aws ecs list-services --cluster CLUSTER_NAME          ║
    ║    aws ecs list-tasks --cluster CLUSTER_NAME             ║
    ║    psql -h RDS_ENDPOINT -U admin -d DB_NAME              ║
    ║                                                           ║
    ╚═══════════════════════════════════════════════════════════╝
    MOTD
    
    # Completar
    echo "Bastion host configured successfully!" > /home/ec2-user/setup-complete.txt
    chown ec2-user:ec2-user /home/ec2-user/setup-complete.txt
  EOF
}

# Instancia EC2 Bastion
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.bastion_instance_type
  key_name      = var.bastion_key_name

  # Configuración de red directamente (sin network_interface deprecated)
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]

  iam_instance_profile = aws_iam_instance_profile.bastion.name
  user_data            = base64encode(local.bastion_user_data)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
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

  depends_on = [aws_eip.bastion]
}

# Asociar EIP con la instancia Bastion
resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}