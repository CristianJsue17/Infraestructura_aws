# ====================================
# RDS - POSTGRESQL DATABASES
# ====================================

# Subnet Group para RDS
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.database_subnets

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# Parameter Group para PostgreSQL 15
resource "aws_db_parameter_group" "postgres15" {
  name   = "${var.project_name}-postgres15-params"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  tags = {
    Name        = "${var.project_name}-postgres15-params"
    Environment = var.environment
  }
}

# RDS Instance para Autenticación
resource "aws_db_instance" "autenticacion" {
  identifier     = "${var.project_name}-autenticacion-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_autenticacion_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  vpc_security_group_ids = [aws_security_group.rds_autenticacion.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.postgres15.name

  # Backup
  backup_retention_period         = 7
  backup_window                   = "03:00-04:00"
  maintenance_window              = "mon:04:00-mon:05:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # High Availability
  multi_az            = false # Cambiar a true para producción
  publicly_accessible = false
  deletion_protection = false # Cambiar a true para producción
  skip_final_snapshot = true  # Cambiar a false para producción
  final_snapshot_identifier = "${var.project_name}-autenticacion-final-snapshot"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Copiar tags
  copy_tags_to_snapshot = true

  tags = {
    Name         = "${var.project_name}-autenticacion-db"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# RDS Instance para Productos
resource "aws_db_instance" "productos" {
  identifier     = "${var.project_name}-productos-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_productos_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  vpc_security_group_ids = [aws_security_group.rds_productos.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.postgres15.name

  # Backup
  backup_retention_period         = 7
  backup_window                   = "03:00-04:00"
  maintenance_window              = "mon:04:00-mon:05:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # High Availability
  multi_az            = false # Cambiar a true para producción
  publicly_accessible = false
  deletion_protection = false # Cambiar a true para producción
  skip_final_snapshot = true  # Cambiar a false para producción
  final_snapshot_identifier = "${var.project_name}-productos-final-snapshot"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  # Copiar tags
  copy_tags_to_snapshot = true

  tags = {
    Name         = "${var.project_name}-productos-db"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# ====================================
# SECRETS MANAGER - CREDENCIALES RDS
# ====================================

# Secret para RDS Autenticación
resource "aws_secretsmanager_secret" "rds_autenticacion" {
  name        = "${var.project_name}-rds-autenticacion-creds-v2"  # ✅ Agregar -v2
  description = "Credenciales para RDS de autenticación"
  recovery_window_in_days = 0  # ✅ Agregar esta línea

  tags = {
    Name        = "${var.project_name}-rds-autenticacion-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "rds_autenticacion" {
  secret_id = aws_secretsmanager_secret.rds_autenticacion.id
  secret_string = jsonencode({
    username     = var.db_username
    password     = var.db_password
    engine       = "postgres"
    host         = aws_db_instance.autenticacion.address
    port         = aws_db_instance.autenticacion.port
    dbname       = var.db_autenticacion_name
    database_url = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.autenticacion.address}:${aws_db_instance.autenticacion.port}/${var.db_autenticacion_name}"
  })
}

# Secret para RDS Productos
resource "aws_secretsmanager_secret" "rds_productos" {
  name        = "${var.project_name}-rds-productos-creds-v2"  # ✅ Agregar -v2
  description = "Credenciales para RDS de productos"
  recovery_window_in_days = 0  # ✅ Agregar esta línea

  tags = {
    Name        = "${var.project_name}-rds-productos-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "rds_productos" {
  secret_id = aws_secretsmanager_secret.rds_productos.id
  secret_string = jsonencode({
    username     = var.db_username
    password     = var.db_password
    engine       = "postgres"
    host         = aws_db_instance.productos.address
    port         = aws_db_instance.productos.port
    dbname       = var.db_productos_name
    database_url = "jdbc:postgresql://${aws_db_instance.productos.address}:${aws_db_instance.productos.port}/${var.db_productos_name}"
  })
}

# Secret para JWT
resource "aws_secretsmanager_secret" "jwt" {
  name        = "${var.project_name}-jwt-secret-v2"  # ✅ Agregar -v2
  description = "JWT secret key para ambos microservicios"
  recovery_window_in_days = 0  # ✅ Agregar esta línea

  tags = {
    Name        = "${var.project_name}-jwt-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    secret_key     = var.jwt_secret
    algorithm      = var.jwt_algorithm
    expire_minutes = var.jwt_expire_minutes
  })
}