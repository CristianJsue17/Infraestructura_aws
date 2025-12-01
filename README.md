terraform/
├── 00-provider.tf              # Providers y backend
├── 01-variables.tf             # TODAS las variables
├── 02-vpc.tf                   # VPC, subnets, NAT
├── 03-eks.tf                   # EKS cluster, node groups, IAM
├── 04-rds.tf                   # Ambas DBs + Secrets Manager
├── 05-nlb.tf                   # NLB interno para VPC Link
├── 06-api-gateway.tf           # API Gateway completo (REST API + VPC Link + WAF)
├── 07-kubernetes-manifests.tf  # Deployments, Services, ConfigMaps
├── 08-monitoring.tf            # CloudWatch, alarmas, SNS
├── 09-bastion.tf               # Bastion host (conectar SHH y verificar todo)
├── 10-outputs.tf               # Todos los outputs
├── 11-eks-auth.tf              # Regla de autenticacion con eks
└── terraform.tfvars            # Valores de variables

## **ORDEN CORRECTO DE DEPLOYMENT**
REQUISITOS:
- Aws cli
- kubercel
- docker desktop

# 1. Crear key pair SSH
cd scripts
bash 1-create-key-pair.sh

# 2. Crear repositorios ECR (solo la primera vez)
cd ../terraform
terraform apply -target=aws_ecr_repository.autenticacion -target=aws_ecr_repository.productos

# 3. Construir y subir imágenes Docker
bash 2-build-and-push.sh

# Esto hace:
- docker build -f Dockerfile.prod -t ECR_URI/autenticacion:latest .
- docker push ECR_URI/autenticacion:latest
- docker build -f Dockerfile.prod -t ECR_URI/productos:latest .
- docker push ECR_URI/productos:latest


# 4. Aplicar infraestructura
cd ../terraform
terraform init
terraform plan
terraform apply

# Esto crea:
 - VPC, subnets, NAT gateways
 - EKS cluster, node group
 - RDS databases
 - NLB, Target Groups
 - API Gateway, VPC Link
 - Bastion host
 - Deployments de Kubernetes

# 5. Instalar kubectl (si no está instalado)
cd ../scripts
bash 5-install-kubectl-and-fix.sh

# Esto hace:
 - Descarga kubectl
 - Configura acceso al cluster
 - Actualiza ConfigMap aws-auth con tu usuario

# 6. Diagnosticar problemas (si los hay)
bash 6-diagnostico-nodeports.sh

# 7. Arreglar security groups (si health checks fallan)
bash 7-fix-security-groups.sh

# Esto hace:
 - Identifica el SG correcto de los nodos
 - Agrega reglas para NodePorts (30000-32767)
 - Verifica que target groups estén healthy

# 8. Probar todos los endpoints
bash 4-test-endpoints-no-jq.sh