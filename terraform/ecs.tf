# ====================================
# ECS FARGATE - CLUSTER Y SERVICIOS
# ====================================

# ====================================
# ECS CLUSTER
# ====================================

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-ecs-cluster"
    Environment = var.environment
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

# ====================================
# CLOUDWATCH LOG GROUPS
# ====================================

resource "aws_cloudwatch_log_group" "autenticacion" {
  name              = "/ecs/${var.project_name}/autenticacion"
  retention_in_days = 7

  tags = {
    Name         = "${var.project_name}-autenticacion-logs"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

resource "aws_cloudwatch_log_group" "productos" {
  name              = "/ecs/${var.project_name}/productos"
  retention_in_days = 7

  tags = {
    Name         = "${var.project_name}-productos-logs"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# ====================================
# TASK DEFINITION - AUTENTICACIÓN
# ====================================

resource "aws_ecs_task_definition" "autenticacion" {
  family                   = "${var.project_name}-autenticacion"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_autenticacion_cpu
  memory                   = var.ecs_autenticacion_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role_autenticacion.arn

  container_definitions = jsonencode([
    {
      name      = "autenticacion"
      image     = "${aws_ecr_repository.autenticacion.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ALGORITHM"
          value = var.jwt_algorithm
        },
        {
          name  = "ACCESS_TOKEN_EXPIRE_MINUTES"
          value = tostring(var.jwt_expire_minutes)
        },
        {
          name  = "PYTHONUNBUFFERED"
          value = "1"
        }
      ]

      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = "${aws_secretsmanager_secret.rds_autenticacion.arn}:database_url::"
        },
        {
          name      = "SECRET_KEY"
          valueFrom = "${aws_secretsmanager_secret.jwt.arn}:secret_key::"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "python -c 'import urllib.request; urllib.request.urlopen(\"http://localhost:8000/health\")' || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 40
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.autenticacion.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name         = "${var.project_name}-autenticacion-task"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# ====================================
# TASK DEFINITION - PRODUCTOS
# ====================================

resource "aws_ecs_task_definition" "productos" {
  family                   = "${var.project_name}-productos"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_productos_cpu
  memory                   = var.ecs_productos_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role_productos.arn

  container_definitions = jsonencode([
    {
      name      = "productos"
      image     = "${aws_ecr_repository.productos.repository_url}:latest"
      essential = true

      # Sobrescribir comando para optimizar JVM
      command = [
        "java",
        "-Xms512m",
        "-Xmx1024m",
        "-XX:+UseG1GC",
        "-XX:MaxGCPauseMillis=200",
        "-jar",
        "app.jar"
      ]

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "AUTH_SERVICE_URL"
          value = "http://${aws_lb.internal.dns_name}"
        }
      ]

      secrets = [
        {
          name      = "SPRING_DATASOURCE_URL"
          valueFrom = "${aws_secretsmanager_secret.rds_productos.arn}:database_url::"
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = "${aws_secretsmanager_secret.rds_productos.arn}:username::"
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.rds_productos.arn}:password::"
        },
        {
          name      = "JWT_SECRET"
          valueFrom = "${aws_secretsmanager_secret.jwt.arn}:secret_key::"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.productos.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name         = "${var.project_name}-productos-task"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# ====================================
# SERVICE DISCOVERY NAMESPACE
# ====================================

# resource "aws_service_discovery_private_dns_namespace" "main" {
#   name        = "${var.project_name}.local"
#   description = "Private DNS namespace for ECS services"
#   vpc         = module.vpc.vpc_id
# 
#   tags = {
#     Name        = "${var.project_name}-service-discovery"
#     Environment = var.environment
#   }
# }

# resource "aws_service_discovery_service" "autenticacion" {
#   name = "autenticacion"
# 
#   dns_config {
#     namespace_id = aws_service_discovery_private_dns_namespace.main.id
# 
#     dns_records {
#       ttl  = 10
#       type = "A"
#     }
# 
#     routing_policy = "MULTIVALUE"
#   }
# 
#   health_check_custom_config {
#     # El bloque está vacío pero es requerido para ECS service discovery
#     # failure_threshold fue removido porque está deprecado
#   }
# 
#   tags = {
#     Name         = "${var.project_name}-autenticacion-discovery"
#     Environment  = var.environment
#     Microservice = "autenticacion"
#   }
# }

# ====================================
# ECS SERVICE - AUTENTICACIÓN
# ====================================

resource "aws_ecs_service" "autenticacion" {
  name            = "${var.project_name}-autenticacion"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.autenticacion.arn
  desired_count   = var.service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.autenticacion.arn
    container_name   = "autenticacion"
    container_port   = 8000
  }

  #   service_registries {
  #     registry_arn = aws_service_discovery_service.autenticacion.arn
  #   }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group.autenticacion
  ]

  tags = {
    Name         = "${var.project_name}-autenticacion-service"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# ====================================
# ECS SERVICE - PRODUCTOS
# ====================================

resource "aws_ecs_service" "productos" {
  name            = "${var.project_name}-productos"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.productos.arn
  desired_count   = var.service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.productos.arn
    container_name   = "productos"
    container_port   = 8080
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.http,
    aws_lb_target_group.productos,
    aws_ecs_service.autenticacion
  ]

  tags = {
    Name         = "${var.project_name}-productos-service"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# ====================================
# AUTO SCALING - AUTENTICACIÓN
# ====================================

resource "aws_appautoscaling_target" "autenticacion" {
  max_capacity       = var.service_max_count
  min_capacity       = var.service_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.autenticacion.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "autenticacion_cpu" {
  name               = "${var.project_name}-autenticacion-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.autenticacion.resource_id
  scalable_dimension = aws_appautoscaling_target.autenticacion.scalable_dimension
  service_namespace  = aws_appautoscaling_target.autenticacion.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "autenticacion_memory" {
  name               = "${var.project_name}-autenticacion-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.autenticacion.resource_id
  scalable_dimension = aws_appautoscaling_target.autenticacion.scalable_dimension
  service_namespace  = aws_appautoscaling_target.autenticacion.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ====================================
# AUTO SCALING - PRODUCTOS
# ====================================

resource "aws_appautoscaling_target" "productos" {
  max_capacity       = var.service_max_count
  min_capacity       = var.service_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.productos.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "productos_cpu" {
  name               = "${var.project_name}-productos-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.productos.resource_id
  scalable_dimension = aws_appautoscaling_target.productos.scalable_dimension
  service_namespace  = aws_appautoscaling_target.productos.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "productos_memory" {
  name               = "${var.project_name}-productos-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.productos.resource_id
  scalable_dimension = aws_appautoscaling_target.productos.scalable_dimension
  service_namespace  = aws_appautoscaling_target.productos.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}