# ====================================
# NETWORK LOAD BALANCER (NLB) - INTERNO
# ====================================

resource "aws_lb" "nlb" {
  name               = "${var.project_name}-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "${var.project_name}-nlb"
    Environment = var.environment
  }
}

# ====================================
# TARGET GROUP - AUTENTICACIÓN
# ====================================

resource "aws_lb_target_group" "autenticacion" {
  name        = "${var.project_name}-auth-tg"
  port        = 30080
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    protocol            = "HTTP"
    path                = "/health"
    port                = "30080"
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
  port        = 30081
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    interval            = 30
    protocol            = "HTTP"
    path                = "/health"
    port                = "30081"
  }

  deregistration_delay = 30

  tags = {
    Name         = "${var.project_name}-prod-tg"
    Environment  = var.environment
    Microservice = "productos"
  }
}

# ====================================
# NLB LISTENER - Puerto 8000 (Autenticación)
# ====================================

resource "aws_lb_listener" "autenticacion" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "8000"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.autenticacion.arn
  }

  tags = {
    Name        = "${var.project_name}-nlb-auth-listener"
    Environment = var.environment
  }
}

# ====================================
# NLB LISTENER - Puerto 8080 (Productos)
# ====================================

resource "aws_lb_listener" "productos" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "8080"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.productos.arn
  }

  tags = {
    Name        = "${var.project_name}-nlb-prod-listener"
    Environment = var.environment
  }
}

# ====================================
# ATTACHMENT - ASG a Target Groups
# ====================================

resource "aws_autoscaling_attachment" "autenticacion" {
  autoscaling_group_name = aws_eks_node_group.main.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.autenticacion.arn
}

resource "aws_autoscaling_attachment" "productos" {
  autoscaling_group_name = aws_eks_node_group.main.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.productos.arn
}