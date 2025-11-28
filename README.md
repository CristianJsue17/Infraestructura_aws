# 🚀 Infraestructura AWS - Microservicios con EKS

Infraestructura como código para desplegar microservicios en AWS EKS usando Terraform y Kubernetes.

## 📋 Requisitos Previos

- [AWS CLI](https://aws.amazon.com/cli/) configurado
- [Terraform](https://www.terraform.io/downloads) v1.5+
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://www.docker.com/)
- Cuenta de AWS con permisos necesarios

## 🏗️ Arquitectura
```
Internet → API Gateway (API Key) → ALB → EKS Cluster
                                          ├── Autenticación (3 réplicas)
                                          └── Productos (3 réplicas)
                                                 ↓
                                          RDS PostgreSQL (2 instancias)
```

## 🔐 Configuración Inicial

### 1. Crear Key Pair para SSH
```bash
cd scripts
chmod +x create-key-pair.sh
./create-key-pair.sh
```

### 2. Configurar variables de Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Editar con tus valores
```

### 3. Inicializar Terraform
```bash
cd terraform
terraform init
```

## 🚀 Despliegue

### Paso 1: Crear infraestructura
```bash
cd terraform
terraform plan
terraform apply
```

Tiempo estimado: **15-20 minutos**

### Paso 2: Configurar kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name microservicios-cluster
kubectl get nodes
```

### Paso 3: Construir y subir imágenes Docker
```bash
cd ../scripts
chmod +x build-and-push.sh
./build-and-push.sh
```

### Paso 4: Desplegar en Kubernetes
```bash
chmod +x deploy-k8s.sh
./deploy-k8s.sh
```

## 🔍 Verificación
```bash
# Ver pods
kubectl get pods -n microservicios

# Ver servicios
kubectl get svc -n microservicios

# Ver logs
kubectl logs -f deployment/autenticacion -n microservicios
kubectl logs -f deployment/productos -n microservicios
```

## 🌐 Acceso a los Servicios

Los servicios están accesibles **únicamente** a través de API Gateway:
```
https://API_GATEWAY_ID.execute-api.us-east-1.amazonaws.com/prod
```

**Endpoints:**
- `POST /api/auth/registrar` - Registrar usuario
- `POST /api/auth/login` - Iniciar sesión
- `GET /api/productos` - Listar productos (requiere token)
- `POST /api/productos` - Crear producto (requiere token)

**Header requerido para API Gateway:**
```
x-api-key: TU_API_KEY
```

## 🔑 Obtener API Key
```bash
cd terraform
terraform output api_gateway_api_key
```

## 🗑️ Destruir Infraestructura
```bash
cd scripts
chmod +x destroy-all.sh
./destroy-all.sh
```

## 📊 Outputs de Terraform

- `eks_cluster_endpoint` - Endpoint del cluster EKS
- `rds_autenticacion_endpoint` - Endpoint RDS Autenticación
- `rds_productos_endpoint` - Endpoint RDS Productos
- `api_gateway_url` - URL de API Gateway
- `api_gateway_api_key` - API Key para acceso
- `bastion_public_ip` - IP del Bastion Host
- `ecr_autenticacion_url` - URL del repositorio ECR Autenticación
- `ecr_productos_url` - URL del repositorio ECR Productos

## 🔧 Troubleshooting

### Problema: Pods en estado CrashLoopBackOff
```bash
kubectl describe pod POD_NAME -n microservicios
kubectl logs POD_NAME -n microservicios
```

### Problema: No puedo conectar a RDS

Verificar security groups y secrets de Kubernetes.

### Problema: API Gateway retorna 403

Verificar que estés enviando el header `x-api-key`.

## 📚 Documentación

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)

## 👥 Autor

Proyecto educativo - Sistemas de Información

## 📄 Licencia

MIT License - Uso educativo