# ====================================
# OUTPUTS - INFORMACIÓN DE INFRAESTRUCTURA
# ====================================

# ====================================
# VPC OUTPUTS
# ====================================

output "vpc_id" {
  description = "ID del VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block del VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "IDs de las subnets privadas"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs de las subnets públicas"
  value       = module.vpc.public_subnets
}

# ====================================
# ECS OUTPUTS
# ====================================

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN del cluster ECS"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_autenticacion_service_name" {
  description = "Nombre del servicio ECS de autenticación"
  value       = aws_ecs_service.autenticacion.name
}

output "ecs_productos_service_name" {
  description = "Nombre del servicio ECS de productos"
  value       = aws_ecs_service.productos.name
}

# ====================================
# ECR OUTPUTS
# ====================================

output "ecr_autenticacion_repository_url" {
  description = "URL del repositorio ECR para autenticación"
  value       = aws_ecr_repository.autenticacion.repository_url
}

output "ecr_productos_repository_url" {
  description = "URL del repositorio ECR para productos"
  value       = aws_ecr_repository.productos.repository_url
}

output "ecr_login_command" {
  description = "Comando para hacer login en ECR"
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

# ====================================
# RDS OUTPUTS
# ====================================

output "rds_autenticacion_endpoint" {
  description = "Endpoint de RDS para autenticación"
  value       = aws_db_instance.autenticacion.endpoint
  sensitive   = true
}

output "rds_autenticacion_address" {
  description = "Address de RDS para autenticación"
  value       = aws_db_instance.autenticacion.address
}

output "rds_productos_endpoint" {
  description = "Endpoint de RDS para productos"
  value       = aws_db_instance.productos.endpoint
  sensitive   = true
}

output "rds_productos_address" {
  description = "Address de RDS para productos"
  value       = aws_db_instance.productos.address
}

# ====================================
# API GATEWAY OUTPUTS
# ====================================

output "api_gateway_id" {
  description = "ID de API Gateway"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_url" {
  description = "URL base de API Gateway"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_gateway_api_key" {
  description = "API Key para acceder a API Gateway"
  value       = aws_api_gateway_api_key.main.value
  sensitive   = true
}

output "api_gateway_endpoints" {
  description = "Endpoints disponibles en API Gateway"
  value = {
    base_url                = aws_api_gateway_stage.main.invoke_url
    autenticacion_registrar = "${aws_api_gateway_stage.main.invoke_url}/api/auth/registrar"
    autenticacion_login     = "${aws_api_gateway_stage.main.invoke_url}/api/auth/login"
    productos_listar        = "${aws_api_gateway_stage.main.invoke_url}/api/productos"
    productos_crear         = "${aws_api_gateway_stage.main.invoke_url}/api/productos"
  }
}

# ====================================
# ALB OUTPUTS
# ====================================

output "alb_dns_name" {
  description = "DNS name del ALB interno"
  value       = aws_lb.internal.dns_name
}

output "alb_arn" {
  description = "ARN del ALB interno"
  value       = aws_lb.internal.arn
}

# ====================================
# BASTION OUTPUTS
# ====================================

output "bastion_public_ip" {
  description = "IP pública del Bastion Host"
  value       = aws_eip.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "Comando SSH para conectar al Bastion"
  value       = "ssh -i ~/.ssh/${var.bastion_key_name}.pem ec2-user@${aws_eip.bastion.public_ip}"
}

# ====================================
# SECRETS MANAGER OUTPUTS
# ====================================

output "secrets_rds_autenticacion_arn" {
  description = "ARN del secret de autenticación"
  value       = aws_secretsmanager_secret.rds_autenticacion.arn
}

output "secrets_rds_productos_arn" {
  description = "ARN del secret de productos"
  value       = aws_secretsmanager_secret.rds_productos.arn
}

output "secrets_jwt_arn" {
  description = "ARN del secret de JWT"
  value       = aws_secretsmanager_secret.jwt.arn
}

# ====================================
# INFORMACIÓN DE LA CUENTA
# ====================================

output "aws_account_id" {
  description = "ID de la cuenta de AWS"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Región de AWS utilizada"
  value       = var.aws_region
}

# ====================================
# COMANDOS ÚTILES
# ====================================

output "useful_commands" {
  description = "Comandos útiles para gestionar la infraestructura"
  value = {
    # ECR
    ecr_login = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

    # ECS - Ver servicios
    ecs_list_services = "aws ecs list-services --cluster ${aws_ecs_cluster.main.name} --region ${var.aws_region}"

    # ECS - Ver tasks
    ecs_list_tasks_auth = "aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --service-name ${aws_ecs_service.autenticacion.name} --region ${var.aws_region}"
    ecs_list_tasks_prod = "aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --service-name ${aws_ecs_service.productos.name} --region ${var.aws_region}"

    # ECS - Force new deployment
    ecs_update_auth = "aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.autenticacion.name} --force-new-deployment --region ${var.aws_region}"
    ecs_update_prod = "aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.productos.name} --force-new-deployment --region ${var.aws_region}"

    # CloudWatch Logs
    logs_auth = "aws logs tail /ecs/${var.project_name}/autenticacion --follow --region ${var.aws_region}"
    logs_prod = "aws logs tail /ecs/${var.project_name}/productos --follow --region ${var.aws_region}"

    # API Key
    get_api_key = "terraform output -raw api_gateway_api_key"

    # SSH to Bastion
    ssh_bastion = "ssh -i ~/.ssh/${var.bastion_key_name}.pem ec2-user@${aws_eip.bastion.public_ip}"
  }
}

# ====================================
# RESUMEN DE INFRAESTRUCTURA
# ====================================

output "infrastructure_summary" {
  description = "Resumen completo de la infraestructura desplegada"
  value = {
    vpc = {
      id   = module.vpc.vpc_id
      cidr = module.vpc.vpc_cidr_block
    }
    ecs = {
      cluster_name = aws_ecs_cluster.main.name
      autenticacion = {
        service_name  = aws_ecs_service.autenticacion.name
        desired_count = aws_ecs_service.autenticacion.desired_count
      }
      productos = {
        service_name  = aws_ecs_service.productos.name
        desired_count = aws_ecs_service.productos.desired_count
      }
    }
    rds = {
      autenticacion_endpoint = aws_db_instance.autenticacion.address
      productos_endpoint     = aws_db_instance.productos.address
    }
    api_gateway = {
      url        = aws_api_gateway_stage.main.invoke_url
      rate_limit = "${var.rate_limit_per_ip} requests/second per IP"
    }
    bastion = {
      public_ip = aws_eip.bastion.public_ip
    }
  }
}

# ====================================
# NOTAS IMPORTANTES POST-DEPLOYMENT
# ====================================

output "important_notes" {
  description = "Notas importantes después del despliegue"
  value       = <<-EOT
    ╔══════════════════════════════════════════════════════════════╗
    ║          INFRAESTRUCTURA ECS FARGATE DESPLEGADA              ║
    ╚══════════════════════════════════════════════════════════════╝
    
    📋 PRÓXIMOS PASOS:
    
    1️⃣  Construir y subir imágenes Docker a ECR:
       cd scripts && ./2-build-and-push.sh
    
    2️⃣  Forzar nuevo despliegue de servicios:
       ./4-update-services.sh
    
    3️⃣  Ver logs de los servicios:
       aws logs tail /ecs/${var.project_name}/autenticacion --follow
       aws logs tail /ecs/${var.project_name}/productos --follow
    
    4️⃣  Obtener API Key:
       terraform output -raw api_gateway_api_key
    
    5️⃣  Probar los endpoints:
       API Gateway URL: ${aws_api_gateway_stage.main.invoke_url}
       Header requerido: x-api-key: <TU_API_KEY>
    
    🔒 RATE LIMITING:
       - Máximo ${var.rate_limit_per_ip} requests por segundo por IP
       - HTTP 429 si se excede el límite
    
    🚀 ACCESO SSH AL BASTION:
       ssh -i ~/.ssh/${var.bastion_key_name}.pem ec2-user@${aws_eip.bastion.public_ip}
    
    📊 MONITOREO:
       - CloudWatch Container Insights: Habilitado
       - Alarmas configuradas para CPU, Memory, errores HTTP
       - SNS Topic: ${var.project_name}-alarms
    
    ╚══════════════════════════════════════════════════════════════╝
  EOT
}