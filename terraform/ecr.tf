# ====================================
# ECR - ELASTIC CONTAINER REGISTRY
# ====================================

# ECR Repository para Autenticación
resource "aws_ecr_repository" "autenticacion" {
  name                 = "${var.project_name}/autenticacion"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name         = "${var.project_name}-autenticacion-repo"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# Lifecycle Policy para Autenticación
resource "aws_ecr_lifecycle_policy" "autenticacion" {
  repository = aws_ecr_repository.autenticacion.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository para Productos
resource "aws_ecr_repository" "productos" {
  name                 = "${var.project_name}/productos"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name         = "${var.project_name}-productos-repo"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# Lifecycle Policy para Productos
resource "aws_ecr_lifecycle_policy" "productos" {
  repository = aws_ecr_repository.productos.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}