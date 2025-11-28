# ====================================
# VARIABLES - CONFIGURACIÓN GENERAL
# ====================================

variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "microservicios"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# ====================================
# VPC CONFIGURATION
# ====================================

variable "vpc_cidr" {
  description = "CIDR block para el VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidad"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# ====================================
# ECS CONFIGURATION
# ====================================

variable "ecs_autenticacion_cpu" {
  description = "CPU units para el task de autenticación (1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "ecs_autenticacion_memory" {
  description = "Memoria en MB para el task de autenticación"
  type        = number
  default     = 1024
}

variable "ecs_productos_cpu" {
  description = "CPU units para el task de productos (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "ecs_productos_memory" {
  description = "Memoria en MB para el task de productos"
  type        = number
  default     = 2048
}

variable "service_desired_count" {
  description = "Número deseado de tasks por servicio"
  type        = number
  default     = 3
}

variable "service_min_count" {
  description = "Número mínimo de tasks por servicio"
  type        = number
  default     = 3
}

variable "service_max_count" {
  description = "Número máximo de tasks por servicio"
  type        = number
  default     = 10
}

# ====================================
# RDS CONFIGURATION
# ====================================

variable "db_instance_class" {
  description = "Clase de instancia para RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Almacenamiento asignado en GB para RDS"
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "Versión de PostgreSQL"
  type        = string
  default     = "15.4"
}

variable "db_username" {
  description = "Usuario master para las bases de datos"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña master para las bases de datos"
  type        = string
  sensitive   = true
}

variable "db_autenticacion_name" {
  description = "Nombre de la base de datos de autenticación"
  type        = string
  default     = "autenticacion_db"
}

variable "db_productos_name" {
  description = "Nombre de la base de datos de productos"
  type        = string
  default     = "productos_db"
}

# ====================================
# JWT CONFIGURATION
# ====================================

variable "jwt_secret" {
  description = "Clave secreta para JWT (debe ser la misma en ambos microservicios)"
  type        = string
  sensitive   = true
}

variable "jwt_algorithm" {
  description = "Algoritmo para JWT"
  type        = string
  default     = "HS256"
}

variable "jwt_expire_minutes" {
  description = "Minutos de expiración del token JWT"
  type        = number
  default     = 30
}

# ====================================
# API GATEWAY CONFIGURATION
# ====================================

variable "api_gateway_stage_name" {
  description = "Nombre del stage de API Gateway"
  type        = string
  default     = "prod"
}

variable "rate_limit_per_ip" {
  description = "Número máximo de requests por segundo por IP"
  type        = number
  default     = 10
}

# ====================================
# BASTION CONFIGURATION
# ====================================

variable "bastion_instance_type" {
  description = "Tipo de instancia para el Bastion Host"
  type        = string
  default     = "t3.micro"
}

variable "bastion_key_name" {
  description = "Nombre de la key pair para el Bastion Host"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks permitidos para SSH al bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"] # CAMBIAR por tu IP en producción
}

# ====================================
# GITHUB REPOSITORIES
# ====================================

variable "github_repo_autenticacion" {
  description = "URL del repositorio de GitHub para autenticación"
  type        = string
}

variable "github_repo_productos" {
  description = "URL del repositorio de GitHub para productos"
  type        = string
}

# ====================================
# TAGS
# ====================================

variable "additional_tags" {
  description = "Tags adicionales para aplicar a todos los recursos"
  type        = map(string)
  default     = {}
}