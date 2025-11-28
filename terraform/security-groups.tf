# ====================================
# SECURITY GROUPS
# ====================================

# Security Group para VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-vpc-endpoints-"
  description = "Security group para VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-vpc-endpoints-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para RDS Autenticación
resource "aws_security_group" "rds_autenticacion" {
  name_prefix = "${var.project_name}-rds-autenticacion-"
  description = "Security group para RDS de autenticacion"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  ingress {
    description     = "PostgreSQL from Bastion"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-rds-autenticacion-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para RDS Productos
resource "aws_security_group" "rds_productos" {
  name_prefix = "${var.project_name}-rds-productos-"
  description = "Security group para RDS de productos"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  ingress {
    description     = "PostgreSQL from Bastion"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-rds-productos-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para Bastion Host
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

# Security Group para Application Load Balancer (interno)
resource "aws_security_group" "alb_internal" {
  name_prefix = "${var.project_name}-alb-internal-"
  description = "Security group for RDS productos"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from anywhere"  # ✅ CAMBIAR descripción
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ✅ CAMBIAR de [var.vpc_cidr] a ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"  # ✅ CAMBIAR descripción
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ✅ CAMBIAR de [var.vpc_cidr] a ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-internal-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project_name}-ecs-tasks-"
  description = "Security group para ECS Fargate tasks"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal.id]
  }

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_internal.id]
  }

  # Permitir comunicación entre tasks (para que productos llame a autenticación)
  ingress {
    description = "Allow communication between ECS tasks"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-ecs-tasks-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}