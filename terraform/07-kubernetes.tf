# ====================================
# KUBERNETES RESOURCES - DEPLOYMENTS, SERVICES, CONFIGMAPS
# ====================================

# ====================================
# NAMESPACE
# ====================================

resource "kubernetes_namespace" "microservicios" {
  metadata {
    name = var.project_name

    labels = {
      name        = var.project_name
      environment = var.environment
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# ====================================
# CONFIGMAP - AUTENTICACIÓN
# ====================================

resource "kubernetes_config_map" "autenticacion" {
  metadata {
    name      = "autenticacion-config"
    namespace = kubernetes_namespace.microservicios.metadata[0].name
  }

  data = {
    ALGORITHM                   = var.jwt_algorithm
    ACCESS_TOKEN_EXPIRE_MINUTES = tostring(var.jwt_expire_minutes)
    PYTHONUNBUFFERED           = "1"
  }
}

# ====================================
# SECRET - AUTENTICACIÓN
# ====================================

resource "kubernetes_secret" "autenticacion" {
  metadata {
    name      = "autenticacion-secrets"
    namespace = kubernetes_namespace.microservicios.metadata[0].name
  }

  data = {
    DATABASE_URL = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.autenticacion.address}:${aws_db_instance.autenticacion.port}/${var.db_autenticacion_name}"
    SECRET_KEY   = var.jwt_secret
  }

  type = "Opaque"
}

# ====================================
# DEPLOYMENT - AUTENTICACIÓN (CORREGIDO)
# ====================================

resource "kubernetes_deployment_v1" "autenticacion" {
  metadata {
    name      = "autenticacion"
    namespace = kubernetes_namespace.microservicios.metadata[0].name

    labels = {
      app         = "autenticacion"
      environment = var.environment
    }
  }

  spec {
    replicas = var.autenticacion_replicas

    selector {
      match_labels = {
        app = "autenticacion"
      }
    }

    template {
      metadata {
        labels = {
          app         = "autenticacion"
          environment = var.environment
        }
      }

      spec {
        container {
          name  = "autenticacion"
          image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_autenticacion_name}:latest"

          port {
            container_port = 8000
            protocol       = "TCP"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.autenticacion.metadata[0].name
            }
          }

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.autenticacion.metadata[0].name
                key  = "DATABASE_URL"
              }
            }
          }

          env {
            name = "SECRET_KEY"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.autenticacion.metadata[0].name
                key  = "SECRET_KEY"
              }
            }
          }

          resources {
            requests = {
              cpu    = var.autenticacion_cpu_request
              memory = var.autenticacion_memory_request
            }
            limits = {
              cpu    = var.autenticacion_cpu_limit
              memory = var.autenticacion_memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 50
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 45
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 6
          }

          image_pull_policy = "Always"
        }
      }
    }
  }

  wait_for_rollout = false

  depends_on = [
    aws_db_instance.autenticacion,
    kubernetes_config_map.autenticacion,
    kubernetes_secret.autenticacion
  ]

  lifecycle {
    ignore_changes = [
      spec[0].template[0].metadata[0].annotations
    ]
  }
}

# ====================================
# SERVICE - AUTENTICACIÓN (NodePort)
# ====================================

resource "kubernetes_service" "autenticacion" {
  metadata {
    name      = "autenticacion-service"
    namespace = kubernetes_namespace.microservicios.metadata[0].name

    labels = {
      app = "autenticacion"
    }
  }

  spec {
    selector = {
      app = "autenticacion"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      node_port   = 30080
      protocol    = "TCP"
    }

    type = "NodePort"
  }

  depends_on = [kubernetes_deployment_v1.autenticacion]
}

# ====================================
# HORIZONTAL POD AUTOSCALER - AUTENTICACIÓN
# ====================================

resource "kubernetes_horizontal_pod_autoscaler_v2" "autenticacion" {
  metadata {
    name      = "autenticacion-hpa"
    namespace = kubernetes_namespace.microservicios.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.autenticacion.metadata[0].name
    }

    min_replicas = var.autenticacion_replicas
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.autenticacion]
}

# ====================================
# CONFIGMAP - PRODUCTOS
# ====================================

resource "kubernetes_config_map" "productos" {
  metadata {
    name      = "productos-config"
    namespace = kubernetes_namespace.microservicios.metadata[0].name
  }

  data = {
    SPRING_PROFILES_ACTIVE = "prod"
  }
}

# ====================================
# SECRET - PRODUCTOS
# ====================================

resource "kubernetes_secret" "productos" {
  metadata {
    name      = "productos-secrets"
    namespace = kubernetes_namespace.microservicios.metadata[0].name
  }

  data = {
    SPRING_DATASOURCE_URL      = "jdbc:postgresql://${aws_db_instance.productos.address}:${aws_db_instance.productos.port}/${var.db_productos_name}"
    SPRING_DATASOURCE_USERNAME = var.db_username
    SPRING_DATASOURCE_PASSWORD = var.db_password
    JWT_SECRET                 = var.jwt_secret
  }

  type = "Opaque"
}

# ====================================
# DEPLOYMENT - PRODUCTOS (CORREGIDO)
# ====================================

resource "kubernetes_deployment_v1" "productos" {
  metadata {
    name      = "productos"
    namespace = kubernetes_namespace.microservicios.metadata[0].name

    labels = {
      app         = "productos"
      environment = var.environment
    }
  }

  spec {
    replicas = var.productos_replicas

    selector {
      match_labels = {
        app = "productos"
      }
    }

    template {
      metadata {
        labels = {
          app         = "productos"
          environment = var.environment
        }
      }

      spec {
        container {
          name  = "productos"
          image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_productos_name}:latest"

          port {
            container_port = 8080
            protocol       = "TCP"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.productos.metadata[0].name
            }
          }

          env {
            name = "SPRING_DATASOURCE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.productos.metadata[0].name
                key  = "SPRING_DATASOURCE_URL"
              }
            }
          }

          env {
            name = "SPRING_DATASOURCE_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.productos.metadata[0].name
                key  = "SPRING_DATASOURCE_USERNAME"
              }
            }
          }

          env {
            name = "SPRING_DATASOURCE_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.productos.metadata[0].name
                key  = "SPRING_DATASOURCE_PASSWORD"
              }
            }
          }

          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.productos.metadata[0].name
                key  = "JWT_SECRET"
              }
            }
          }

          resources {
            requests = {
              cpu    = var.productos_cpu_request
              memory = var.productos_memory_request
            }
            limits = {
              cpu    = var.productos_cpu_limit
              memory = var.productos_memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 90
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 60
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 6
          }

          image_pull_policy = "Always"
        }
      }
    }
  }

  wait_for_rollout = false

  depends_on = [
    aws_db_instance.productos,
    kubernetes_config_map.productos,
    kubernetes_secret.productos
  ]

  lifecycle {
    ignore_changes = [
      spec[0].template[0].metadata[0].annotations
    ]
  }
}

# ====================================
# SERVICE - PRODUCTOS (NodePort)
# ====================================

resource "kubernetes_service" "productos" {
  metadata {
    name      = "productos-service"
    namespace = kubernetes_namespace.microservicios.metadata[0].name

    labels = {
      app = "productos"
    }
  }

  spec {
    selector = {
      app = "productos"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      node_port   = 30081
      protocol    = "TCP"
    }

    type = "NodePort"
  }

  depends_on = [kubernetes_deployment_v1.productos]
}

# ====================================
# HORIZONTAL POD AUTOSCALER - PRODUCTOS
# ====================================

resource "kubernetes_horizontal_pod_autoscaler_v2" "productos" {
  metadata {
    name      = "productos-hpa"
    namespace = kubernetes_namespace.microservicios.metadata[0].name
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.productos.metadata[0].name
    }

    min_replicas = var.productos_replicas
    max_replicas = 10

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }

  depends_on = [kubernetes_deployment_v1.productos]
}