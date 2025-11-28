# ====================================
# VPC - VIRTUAL PRIVATE CLOUD
# ====================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i + length(var.availability_zones))]
  database_subnets = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 4, i + 2 * length(var.availability_zones))]

  # NAT Gateway
  enable_nat_gateway     = true
  single_nat_gateway     = false # Una por AZ para alta disponibilidad
  one_nat_gateway_per_az = true

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  # Tags para subnets públicas
  public_subnet_tags = {
    Name = "${var.project_name}-public-subnet"
    Tier = "Public"
  }

  # Tags para subnets privadas
  private_subnet_tags = {
    Name = "${var.project_name}-private-subnet"
    Tier = "Private"
  }

  # Tags para subnets de base de datos
  database_subnet_tags = {
    Name = "${var.project_name}-database-subnet"
    Tier = "Database"
  }

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# ====================================
# VPC ENDPOINTS - REDUCIR COSTOS
# ====================================

# S3 Gateway Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.public_route_table_ids
  )

  tags = {
    Name        = "${var.project_name}-s3-endpoint"
    Environment = var.environment
  }
}

# ECR API Interface Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-ecr-api-endpoint"
    Environment = var.environment
  }
}

# ECR Docker Interface Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-ecr-dkr-endpoint"
    Environment = var.environment
  }
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-logs-endpoint"
    Environment = var.environment
  }
}

# Secrets Manager Interface Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-secretsmanager-endpoint"
    Environment = var.environment
  }
}