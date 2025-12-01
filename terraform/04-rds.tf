# ====================================
# RDS - POSTGRESQL DATABASES (CORREGIDO v2)
# ====================================

# ====================================
# SECURITY GROUP - RDS AUTENTICACIÓN
# ====================================

resource "aws_security_group" "rds_autenticacion" {
  name_prefix = "${var.project_name}-rds-auth-"
  description = "Security group for RDS autenticacion database"
  vpc_id      = module.vpc.vpc_id

  # ✅ CRÍTICO: Permitir desde el Cluster Security Group (creado automáticamente por EKS)
  ingress {
    description     = "PostgreSQL from EKS Cluster SG (auto-created)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  # ✅ También permitir desde el SG de nodos (por si acaso)
  ingress {
    description     = "PostgreSQL from EKS nodes SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # ✅ Permitir conexiones desde Bastion para debugging
  ingress {
    description     = "PostgreSQL from Bastion"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # ✅ Permitir desde toda la VPC (fallback)
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
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
    Name        = "${var.project_name}-rds-autenticacion-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ====================================
# SECURITY GROUP - RDS PRODUCTOS
# ====================================

resource "aws_security_group" "rds_productos" {
  name_prefix = "${var.project_name}-rds-prod-"
  description = "Security group for RDS productos database"
  vpc_id      = module.vpc.vpc_id

  # ✅ CRÍTICO: Permitir desde el Cluster Security Group (creado automáticamente por EKS)
  ingress {
    description     = "PostgreSQL from EKS Cluster SG (auto-created)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  # ✅ También permitir desde el SG de nodos (por si acaso)
  ingress {
    description     = "PostgreSQL from EKS nodes SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # ✅ Permitir conexiones desde Bastion para debugging
  ingress {
    description     = "PostgreSQL from Bastion"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # ✅ Permitir desde toda la VPC (fallback)
  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
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
    Name        = "${var.project_name}-rds-productos-sg"
    Environment = var.environment
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ====================================
# DB SUBNET GROUP - USAR SUBNETS PRIVADAS
# ====================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# ====================================
# DB PARAMETER GROUP
# ====================================

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

# ====================================
# RDS INSTANCE - AUTENTICACIÓN
# ====================================

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
  multi_az               = false
  publicly_accessible    = false
  deletion_protection    = false
  skip_final_snapshot    = true
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
  
  depends_on = [aws_eks_cluster.main]
}

# ====================================
# RDS INSTANCE - PRODUCTOS
# ====================================

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
  multi_az               = false
  publicly_accessible    = false
  deletion_protection    = false
  skip_final_snapshot    = true
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
  
  depends_on = [aws_eks_cluster.main]
}

# ====================================
# SECRETS MANAGER - CREDENCIALES RDS
# ====================================

# Secret para RDS Autenticación
resource "aws_secretsmanager_secret" "rds_autenticacion" {
  name                    = "${var.project_name}-rds-autenticacion-creds"
  description             = "Credenciales para RDS de autenticación"
  recovery_window_in_days = 0

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
  name                    = "${var.project_name}-rds-productos-creds"
  description             = "Credenciales para RDS de productos"
  recovery_window_in_days = 0

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
  name                    = "${var.project_name}-jwt-secret"
  description             = "JWT secret key para ambos microservicios"
  recovery_window_in_days = 0

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
