# ====================================
# CLOUDWATCH - MONITORING Y ALARMAS
# ====================================

# ====================================
# SNS TOPIC PARA ALARMAS
# ====================================

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms"

  tags = {
    Name        = "${var.project_name}-alarms-topic"
    Environment = var.environment
  }
}

# ====================================
# ALARMAS - ECS SERVICES
# ====================================

# Alarma: CPU Alta - Autenticación
resource "aws_cloudwatch_metric_alarm" "ecs_autenticacion_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-autenticacion-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU alta en servicio de autenticación"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.autenticacion.name
  }

  tags = {
    Name         = "${var.project_name}-ecs-auth-cpu-alarm"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# Alarma: Memory Alta - Autenticación
resource "aws_cloudwatch_metric_alarm" "ecs_autenticacion_memory_high" {
  alarm_name          = "${var.project_name}-ecs-autenticacion-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Memoria alta en servicio de autenticación"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.autenticacion.name
  }

  tags = {
    Name         = "${var.project_name}-ecs-auth-memory-alarm"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# Alarma: CPU Alta - Productos
resource "aws_cloudwatch_metric_alarm" "ecs_productos_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-productos-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU alta en servicio de productos"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.productos.name
  }

  tags = {
    Name         = "${var.project_name}-ecs-prod-cpu-alarm"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# Alarma: Memory Alta - Productos
resource "aws_cloudwatch_metric_alarm" "ecs_productos_memory_high" {
  alarm_name          = "${var.project_name}-ecs-productos-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Memoria alta en servicio de productos"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.productos.name
  }

  tags = {
    Name         = "${var.project_name}-ecs-prod-memory-alarm"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# ====================================
# ALARMAS - RDS
# ====================================

# Alarma: CPU Alta - RDS Autenticación
resource "aws_cloudwatch_metric_alarm" "rds_autenticacion_cpu_high" {
  alarm_name          = "${var.project_name}-rds-autenticacion-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU alta en RDS Autenticación"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.autenticacion.id
  }

  tags = {
    Name         = "${var.project_name}-rds-auth-cpu-alarm"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# Alarma: CPU Alta - RDS Productos
resource "aws_cloudwatch_metric_alarm" "rds_productos_cpu_high" {
  alarm_name          = "${var.project_name}-rds-productos-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU alta en RDS Productos"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.productos.id
  }

  tags = {
    Name         = "${var.project_name}-rds-prod-cpu-alarm"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# ====================================
# ALARMAS - ALB
# ====================================

# Alarma: Target Unhealthy
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.project_name}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Hay targets unhealthy en el ALB"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.internal.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-alb-unhealthy-alarm"
    Environment = var.environment
  }
}

# Alarma: HTTP 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Muchos errores 5xx en el ALB"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.internal.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-alb-5xx-alarm"
    Environment = var.environment
  }
}

# ====================================
# ALARMAS - API GATEWAY
# ====================================

# Alarma: 4xx Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  alarm_name          = "${var.project_name}-api-gateway-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "Muchos errores 4xx en API Gateway"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = {
    Name        = "${var.project_name}-apigw-4xx-alarm"
    Environment = var.environment
  }
}

# Alarma: 5xx Errors
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "${var.project_name}-api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Errores 5xx en API Gateway"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = {
    Name        = "${var.project_name}-apigw-5xx-alarm"
    Environment = var.environment
  }
}

# ====================================
# ALARMAS - WAF RATE LIMITING
# ====================================

# Alarma: Muchas IPs bloqueadas por rate limit
resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_blocks" {
  alarm_name          = "${var.project_name}-waf-rate-limit-blocks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "Muchas requests bloqueadas por rate limiting"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    WebACL = aws_wafv2_web_acl.api_gateway.name
    Region = var.aws_region
    Rule   = "RateLimitPerIP"
  }

  tags = {
    Name        = "${var.project_name}-waf-blocks-alarm"
    Environment = var.environment
  }
}