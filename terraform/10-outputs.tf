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
# EKS OUTPUTS
# ====================================

output "eks_cluster_name" {
  description = "Nombre del cluster EKS"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint del cluster EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "Versión de Kubernetes del cluster"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_arn" {
  description = "ARN del cluster EKS"
  value       = aws_eks_cluster.main.arn
}

output "eks_node_group_name" {
  description = "Nombre del node group"
  value       = aws_eks_node_group.main.node_group_name
}

output "eks_oidc_provider_arn" {
  description = "ARN del OIDC provider de EKS"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# ====================================
# ECR OUTPUTS
# ====================================

output "ecr_autenticacion_repository_url" {
  description = "URL del repositorio ECR para autenticación"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_autenticacion_name}"
}

output "ecr_productos_repository_url" {
  description = "URL del repositorio ECR para productos"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_productos_name}"
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
# NLB OUTPUTS
# ====================================

output "nlb_dns_name" {
  description = "DNS name del NLB interno"
  value       = aws_lb.nlb.dns_name
}

output "nlb_arn" {
  description = "ARN del NLB interno"
  value       = aws_lb.nlb.arn
}

output "nlb_zone_id" {
  description = "Zone ID del NLB"
  value       = aws_lb.nlb.zone_id
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

output "api_gateway_vpc_link_id" {
  description = "ID del VPC Link"
  value       = aws_api_gateway_vpc_link.main.id
}

output "api_gateway_endpoints" {
  description = "Endpoints disponibles en API Gateway"
  value = {
    base_url                = aws_api_gateway_stage.main.invoke_url
    autenticacion_registrar = "${aws_api_gateway_stage.main.invoke_url}/api/auth/registrar"
    autenticacion_login     = "${aws_api_gateway_stage.main.invoke_url}/api/auth/login"
    autenticacion_verificar = "${aws_api_gateway_stage.main.invoke_url}/api/auth/verificar"
    productos_listar        = "${aws_api_gateway_stage.main.invoke_url}/api/productos"
    productos_crear         = "${aws_api_gateway_stage.main.invoke_url}/api/productos"
  }
}

# ====================================
# BASTION OUTPUTS
# ====================================

output "bastion_public_ip" {
  description = "IP pública del Bastion Host"
  value       = aws_eip.bastion.public_ip
}

output "bastion_instance_id" {
  description = "ID de la instancia del Bastion"
  value       = aws_instance.bastion.id
}

output "bastion_ssh_command" {
  description = "Comando SSH para conectar al Bastion"
  value       = "ssh -i ~/.ssh/${var.bastion_key_name}.pem ec2-user@${aws_eip.bastion.public_ip}"
}

# ====================================
# KUBERNETES OUTPUTS
# ====================================

output "kubernetes_namespace" {
  description = "Namespace de Kubernetes para los microservicios"
  value       = kubernetes_namespace.microservicios.metadata[0].name
}

output "autenticacion_service_nodeport" {
  description = "NodePort del servicio de autenticación"
  value       = kubernetes_service.autenticacion.spec[0].port[0].node_port
}

output "productos_service_nodeport" {
  description = "NodePort del servicio de productos"
  value       = kubernetes_service.productos.spec[0].port[0].node_port
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
  sensitive   = true
  value = {
    # ECR
    ecr_login = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"

    # EKS - Configurar kubectl
    eks_configure_kubectl = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.aws_region}"

    # Kubernetes - Ver recursos
    k8s_get_pods        = "kubectl get pods -n ${kubernetes_namespace.microservicios.metadata[0].name}"
    k8s_get_services    = "kubectl get services -n ${kubernetes_namespace.microservicios.metadata[0].name}"
    k8s_get_deployments = "kubectl get deployments -n ${kubernetes_namespace.microservicios.metadata[0].name}"

    # Kubernetes - Logs
    k8s_logs_auth = "kubectl logs -f -l app=autenticacion -n ${kubernetes_namespace.microservicios.metadata[0].name}"
    k8s_logs_prod = "kubectl logs -f -l app=productos -n ${kubernetes_namespace.microservicios.metadata[0].name}"

    # Kubernetes - Escalado manual
    k8s_scale_auth = "kubectl scale deployment autenticacion --replicas=5 -n ${kubernetes_namespace.microservicios.metadata[0].name}"
    k8s_scale_prod = "kubectl scale deployment productos --replicas=5 -n ${kubernetes_namespace.microservicios.metadata[0].name}"

    # Kubernetes - Restart deployments
    k8s_restart_auth = "kubectl rollout restart deployment autenticacion -n ${kubernetes_namespace.microservicios.metadata[0].name}"
    k8s_restart_prod = "kubectl rollout restart deployment productos -n ${kubernetes_namespace.microservicios.metadata[0].name}"

    # API Key
    get_api_key = "terraform output -raw api_gateway_api_key"

    # SSH to Bastion
    ssh_bastion = "ssh -i ~/.ssh/${var.bastion_key_name}.pem ec2-user@${aws_eip.bastion.public_ip}"

    # Connect to RDS from Bastion
    psql_autenticacion = "psql -h ${aws_db_instance.autenticacion.address} -U ${var.db_username} -d ${var.db_autenticacion_name}"
    psql_productos     = "psql -h ${aws_db_instance.productos.address} -U ${var.db_username} -d ${var.db_productos_name}"
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
    eks = {
      cluster_name    = aws_eks_cluster.main.name
      cluster_version = aws_eks_cluster.main.version
      node_group      = aws_eks_node_group.main.node_group_name
      node_count      = "${var.eks_node_min_size} - ${var.eks_node_max_size}"
    }
    kubernetes = {
      namespace           = kubernetes_namespace.microservicios.metadata[0].name
      autenticacion_pods  = var.autenticacion_replicas
      productos_pods      = var.productos_replicas
    }
    rds = {
      autenticacion_endpoint = aws_db_instance.autenticacion.address
      productos_endpoint     = aws_db_instance.productos.address
    }
    nlb = {
      dns_name = aws_lb.nlb.dns_name
      internal = "true"
    }
    api_gateway = {
      url         = aws_api_gateway_stage.main.invoke_url
      vpc_link_id = aws_api_gateway_vpc_link.main.id
      rate_limit  = "${var.rate_limit_per_ip} requests/second per IP"
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
    ║        INFRAESTRUCTURA EKS + API GATEWAY DESPLEGADA          ║
    ╚══════════════════════════════════════════════════════════════╝
    
    📋 PRÓXIMOS PASOS:
    
    1️⃣  Construir y subir imágenes Docker a ECR:
       cd scripts && ./2-build-and-push.sh
    
    2️⃣  Reiniciar deployments de Kubernetes:
       kubectl rollout restart deployment autenticacion -n ${kubernetes_namespace.microservicios.metadata[0].name}
       kubectl rollout restart deployment productos -n ${kubernetes_namespace.microservicios.metadata[0].name}
    
    3️⃣  Verificar pods:
       kubectl get pods -n ${kubernetes_namespace.microservicios.metadata[0].name}
    
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
       - CloudWatch Dashboard: microservicios-dashboard
       - Container Insights: Habilitado
       - Alarmas configuradas para CPU, Memory, errores HTTP
    
    🎯 ARQUITECTURA:
       Internet → API Gateway (API Key + WAF) → VPC Link → NLB → EKS Pods → RDS
    
    ╚══════════════════════════════════════════════════════════════╝
  EOT
}

# ====================================
# TESTING COMMANDS
# ====================================

output "testing_commands" {
  description = "Comandos para probar la API"
  sensitive   = true
  value = {
    set_variables = <<-EOT
      export API_URL="${aws_api_gateway_stage.main.invoke_url}"
      export API_KEY=$(terraform output -raw api_gateway_api_key)
    EOT

    register_user = <<-EOT
      curl -X POST "$API_URL/api/auth/registrar" \
        -H "x-api-key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
          "nombre_usuario": "admin",
          "email": "admin@test.com",
          "contrasena": "Admin123!",
          "nombre_completo": "Administrador"
        }'
    EOT

    login = <<-EOT
      curl -X POST "$API_URL/api/auth/login" \
        -H "x-api-key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
          "nombre_usuario": "admin",
          "contrasena": "Admin123!"
        }'
    EOT

    create_product = <<-EOT
      export TOKEN="<token-from-login>"
      curl -X POST "$API_URL/api/productos" \
        -H "x-api-key: $API_KEY" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
          "nombre": "Laptop HP",
          "descripcion": "Laptop empresarial",
          "precio": 1200.00,
          "stock": 10,
          "categoria": "Electrónica",
          "codigoProducto": "LAP-001",
          "estaActivo": true
        }'
    EOT

    list_products = <<-EOT
      curl -X GET "$API_URL/api/productos" \
        -H "x-api-key: $API_KEY" \
        -H "Authorization: Bearer $TOKEN"
    EOT
  }
}