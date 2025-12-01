# ====================================
# MONITORING - CLOUDWATCH + ALARMAS + SNS
# ====================================

# ====================================
# SNS TOPIC - ALARMAS
# ====================================

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-alarms"

  tags = {
    Name        = "${var.project_name}-alarms-topic"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "alarms_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = "admin@example.com" # Cambiar por tu email
}

# ====================================
# CLOUDWATCH ALARMAS - EKS CLUSTER
# ====================================

# Alarma: CPU alta en EKS nodes
resource "aws_cloudwatch_metric_alarm" "eks_node_cpu_high" {
  alarm_name          = "${var.project_name}-eks-node-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU alta en nodos de EKS"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = aws_eks_cluster.main.name
  }

  tags = {
    Name        = "${var.project_name}-eks-node-cpu-high"
    Environment = var.environment
  }
}

# Alarma: Memoria alta en EKS nodes
resource "aws_cloudwatch_metric_alarm" "eks_node_memory_high" {
  alarm_name          = "${var.project_name}-eks-node-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "node_memory_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "Memoria alta en nodos de EKS"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = aws_eks_cluster.main.name
  }

  tags = {
    Name        = "${var.project_name}-eks-node-memory-high"
    Environment = var.environment
  }
}

# ====================================
# CLOUDWATCH ALARMAS - RDS
# ====================================

# Alarma: CPU alta en RDS Autenticación
resource "aws_cloudwatch_metric_alarm" "rds_autenticacion_cpu_high" {
  alarm_name          = "${var.project_name}-rds-autenticacion-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU alta en RDS de autenticación"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.autenticacion.id
  }

  tags = {
    Name        = "${var.project_name}-rds-autenticacion-cpu-high"
    Environment = var.environment
  }
}

# Alarma: CPU alta en RDS Productos
resource "aws_cloudwatch_metric_alarm" "rds_productos_cpu_high" {
  alarm_name          = "${var.project_name}-rds-productos-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "CPU alta en RDS de productos"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.productos.id
  }

  tags = {
    Name        = "${var.project_name}-rds-productos-cpu-high"
    Environment = var.environment
  }
}

# Alarma: Almacenamiento bajo en RDS
resource "aws_cloudwatch_metric_alarm" "rds_autenticacion_storage_low" {
  alarm_name          = "${var.project_name}-rds-autenticacion-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2 GB en bytes
  alarm_description   = "Almacenamiento bajo en RDS de autenticación"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.autenticacion.id
  }

  tags = {
    Name        = "${var.project_name}-rds-autenticacion-storage-low"
    Environment = var.environment
  }
}

# ====================================
# CLOUDWATCH ALARMAS - NLB
# ====================================

# Alarma: Targets unhealthy en NLB
resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy_targets" {
  alarm_name          = "${var.project_name}-nlb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Targets unhealthy en NLB"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.nlb.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-nlb-unhealthy-targets"
    Environment = var.environment
  }
}

# ====================================
# CLOUDWATCH ALARMAS - API GATEWAY
# ====================================

# Alarma: Errores 5xx en API Gateway
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "${var.project_name}-api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
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
    Name        = "${var.project_name}-api-gateway-5xx-errors"
    Environment = var.environment
  }
}

# Alarma: Errores 4xx en API Gateway
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  alarm_name          = "${var.project_name}-api-gateway-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "50"
  alarm_description   = "Errores 4xx en API Gateway"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = {
    Name        = "${var.project_name}-api-gateway-4xx-errors"
    Environment = var.environment
  }
}

# Alarma: Latencia alta en API Gateway
resource "aws_cloudwatch_metric_alarm" "api_gateway_latency_high" {
  alarm_name          = "${var.project_name}-api-gateway-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000" # 5 segundos
  alarm_description   = "Latencia alta en API Gateway"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = {
    Name        = "${var.project_name}-api-gateway-latency-high"
    Environment = var.environment
  }
}

# ====================================
# CLOUDWATCH ALARMAS - WAF
# ====================================

# Alarma: Rate limit blocks en WAF
resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_blocks" {
  alarm_name          = "${var.project_name}-waf-rate-limit-blocks"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = "100"
  alarm_description   = "Alto número de requests bloqueados por rate limiting"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    WebACL = aws_wafv2_web_acl.api_gateway.name
    Region = var.aws_region
    Rule   = "RateLimitPerIP"
  }

  tags = {
    Name        = "${var.project_name}-waf-rate-limit-blocks"
    Environment = var.environment
  }
}

# ====================================
# CLOUDWATCH DASHBOARD
# ====================================

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", { stat = "Sum", label = "Total Requests" }],
            [".", "5XXError", { stat = "Sum", label = "5XX Errors" }],
            [".", "4XXError", { stat = "Sum", label = "4XX Errors" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "API Gateway - Requests"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", { stat = "Average", label = "Average Latency" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "API Gateway - Latency"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", { stat = "Average", label = "Autenticacion DB" }],
            ["...", { stat = "Average", label = "Productos DB" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS - CPU Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", { stat = "Average", label = "EKS Nodes CPU" }],
            [".", "node_memory_utilization", { stat = "Average", label = "EKS Nodes Memory" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "EKS - Node Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["AWS/WAFV2", "BlockedRequests", { stat = "Sum", label = "Blocked Requests" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "WAF - Blocked Requests"
        }
      }
    ]
  })
}

# ====================================
# CONTAINER INSIGHTS - EKS
# ====================================

# ELIMINADO - Container Insights ya se habilita en la creación del cluster
# Los logs ya están habilitados en aws_eks_cluster.main