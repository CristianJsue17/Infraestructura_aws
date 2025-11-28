# ====================================
# IAM ROLES - ECS FARGATE
# ====================================

# ====================================
# ECS TASK EXECUTION ROLE
# ====================================
# Este rol permite a ECS:
# - Hacer pull de imágenes desde ECR
# - Escribir logs en CloudWatch
# - Leer secrets desde Secrets Manager

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-execution-role"
    Environment = var.environment
  }
}

# Política administrada de AWS para ejecución de tasks
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Política personalizada para acceso a Secrets Manager
resource "aws_iam_role_policy" "ecs_task_execution_secrets_policy" {
  name = "${var.project_name}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

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
          aws_secretsmanager_secret.rds_autenticacion.arn,
          aws_secretsmanager_secret.rds_productos.arn,
          aws_secretsmanager_secret.jwt.arn
        ]
      }
    ]
  })
}

# ====================================
# ECS TASK ROLE - AUTENTICACIÓN
# ====================================
# Este rol permite al contenedor de autenticación:
# - Acceder a Secrets Manager
# - Escribir logs adicionales si es necesario

resource "aws_iam_role" "ecs_task_role_autenticacion" {
  name = "${var.project_name}-ecs-task-role-autenticacion"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name         = "${var.project_name}-ecs-task-role-autenticacion"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# Política para acceder a Secrets Manager desde el contenedor
resource "aws_iam_role_policy" "ecs_task_role_autenticacion_secrets" {
  name = "${var.project_name}-autenticacion-secrets-policy"
  role = aws_iam_role.ecs_task_role_autenticacion.id

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
          aws_secretsmanager_secret.rds_autenticacion.arn,
          aws_secretsmanager_secret.jwt.arn
        ]
      }
    ]
  })
}

# ====================================
# ECS TASK ROLE - PRODUCTOS
# ====================================
# Este rol permite al contenedor de productos:
# - Acceder a Secrets Manager
# - Escribir logs adicionales si es necesario

resource "aws_iam_role" "ecs_task_role_productos" {
  name = "${var.project_name}-ecs-task-role-productos"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name         = "${var.project_name}-ecs-task-role-productos"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# Política para acceder a Secrets Manager desde el contenedor
resource "aws_iam_role_policy" "ecs_task_role_productos_secrets" {
  name = "${var.project_name}-productos-secrets-policy"
  role = aws_iam_role.ecs_task_role_productos.id

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
          aws_secretsmanager_secret.rds_productos.arn,
          aws_secretsmanager_secret.jwt.arn
        ]
      }
    ]
  })
}