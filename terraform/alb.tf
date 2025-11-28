# ====================================
# APPLICATION LOAD BALANCER (INTERNO)
# ====================================

resource "aws_lb" "internal" {
  name               = "${var.project_name}-internal-alb"
  internal           = false  # ✅ CAMBIAR de true a false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_internal.id]
  subnets            = module.vpc.public_subnets  # ✅ CAMBIAR de private a public

  enable_deletion_protection       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "${var.project_name}-internal-alb"
    Environment = var.environment
  }
}

# ====================================
# TARGET GROUP - AUTENTICACIÓN
# ====================================

resource "aws_lb_target_group" "autenticacion" {
  name        = "${var.project_name}-auth-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  tags = {
    Name         = "${var.project_name}-auth-tg"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# ====================================
# TARGET GROUP - PRODUCTOS
# ====================================

resource "aws_lb_target_group" "productos" {
  name        = "${var.project_name}-prod-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
    protocol            = "HTTP"
  }

  deregistration_delay = 30

  tags = {
    Name         = "${var.project_name}-prod-tg"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# ====================================
# LISTENER HTTP
# ====================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  tags = {
    Name        = "${var.project_name}-http-listener"
    Environment = var.environment
  }
}

# ====================================
# LISTENER RULES
# ====================================

# Rule para Autenticación
resource "aws_lb_listener_rule" "autenticacion" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.autenticacion.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth/*"]
    }
  }

  tags = {
    Name         = "${var.project_name}-auth-rule"
    Environment  = var.environment
    Microservice = "autenticacion"
  }
}

# Rule para Productos
resource "aws_lb_listener_rule" "productos" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.productos.arn
  }

  condition {
    path_pattern {
      values = ["/api/productos/*"]
    }
  }

  tags = {
    Name         = "${var.project_name}-prod-rule"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# Health check endpoint para el ALB
resource "aws_lb_listener_rule" "health" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "OK"
      status_code  = "200"
    }
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }

  tags = {
    Name        = "${var.project_name}-health-rule"
    Environment = var.environment
  }
}