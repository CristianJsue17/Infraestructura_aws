# ====================================
# API GATEWAY + WAF (RATE LIMITING)
# ====================================

# ====================================
# API GATEWAY REST API
# ====================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API Gateway para microservicios con rate limiting"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-api-gateway"
    Environment = var.environment
  }
}

# ====================================
# API KEY Y USAGE PLAN
# ====================================

resource "aws_api_gateway_api_key" "main" {
  name    = "${var.project_name}-api-key"
  enabled = true

  tags = {
    Name        = "${var.project_name}-api-key"
    Environment = var.environment
  }
}

resource "aws_api_gateway_usage_plan" "main" {
  name        = "${var.project_name}-usage-plan"
  description = "Usage plan con rate limiting"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = 100000
    period = "DAY"
  }

  throttle_settings {
    burst_limit = 100
    rate_limit  = 50
  }

  tags = {
    Name        = "${var.project_name}-usage-plan"
    Environment = var.environment
  }
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.main.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}

# ====================================
# RESOURCES Y METODOS
# ====================================

# Resource: /api
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "api"
}

# Resource: /api/auth
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "auth"
}

# Resource: /api/auth/{proxy+}
resource "aws_api_gateway_resource" "auth_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "{proxy+}"
}

# Method: ANY /api/auth/{proxy+}
resource "aws_api_gateway_method" "auth_proxy" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.auth_proxy.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integration: /api/auth/{proxy+} - Conexion directa al ALB
resource "aws_api_gateway_integration" "auth_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.auth_proxy.id
  http_method = aws_api_gateway_method.auth_proxy.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${aws_lb.internal.dns_name}/api/auth/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# Resource: /api/productos
resource "aws_api_gateway_resource" "productos" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "productos"
}

# Resource: /api/productos/{proxy+}
resource "aws_api_gateway_resource" "productos_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.productos.id
  path_part   = "{proxy+}"
}

# Method: ANY /api/productos/{proxy+}
resource "aws_api_gateway_method" "productos_proxy" {
  rest_api_id      = aws_api_gateway_rest_api.main.id
  resource_id      = aws_api_gateway_resource.productos_proxy.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Integration: /api/productos/{proxy+} - Conexion directa al ALB
resource "aws_api_gateway_integration" "productos_proxy" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.productos_proxy.id
  http_method = aws_api_gateway_method.productos_proxy.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "http://${aws_lb.internal.dns_name}/api/productos/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ====================================
# DEPLOYMENT Y STAGE
# ====================================

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.api.id,
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_resource.auth_proxy.id,
      aws_api_gateway_method.auth_proxy.id,
      aws_api_gateway_integration.auth_proxy.id,
      aws_api_gateway_resource.productos.id,
      aws_api_gateway_resource.productos_proxy.id,
      aws_api_gateway_method.productos_proxy.id,
      aws_api_gateway_integration.productos_proxy.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.auth_proxy,
    aws_api_gateway_integration.productos_proxy
  ]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.api_gateway_stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = {
    Name        = "${var.project_name}-api-stage"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-api-gateway-logs"
    Environment = var.environment
  }
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    logging_level      = "INFO"
    data_trace_enabled = true
  }
}

# ====================================
# WAF - WEB APPLICATION FIREWALL
# Rate Limiting: 10 requests por segundo por IP
# ====================================

resource "aws_wafv2_web_acl" "api_gateway" {
  name  = "${var.project_name}-api-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Rate Limiting por IP
  rule {
    name     = "RateLimitPerIP"
    priority = 1

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate_limit_exceeded"
        }
      }
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_ip * 60 # 10 req/s = 600 req/min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIP"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf-metrics"
    sampled_requests_enabled   = true
  }

  custom_response_body {
    key          = "rate_limit_exceeded"
    content      = jsonencode({
      error   = "Rate limit exceeded"
      message = "You have exceeded the rate limit of ${var.rate_limit_per_ip} requests per second. Please try again later."
    })
    content_type = "APPLICATION_JSON"
  }

  tags = {
    Name        = "${var.project_name}-api-waf"
    Environment = var.environment
  }
}

# Asociar WAF con API Gateway
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway.arn
}