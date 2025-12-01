#!/bin/bash

# ====================================
# SCRIPT DE DESPLIEGUE COMPLETO
# ====================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
REGION="us-east-1"
PROJECT_NAME="microservicios"

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      DESPLIEGUE COMPLETO - EKS + API GATEWAY + NLB          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ====================================
# FUNCIÓN: Mostrar paso
# ====================================
show_step() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ====================================
# PASO 1: Verificar prerequisites
# ====================================
show_step "PASO 1/8: Verificando prerequisites"

# Verificar Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}ERROR: Terraform no está instalado${NC}"
    echo "Instálalo desde: https://www.terraform.io/downloads"
    exit 1
fi
echo -e "${GREEN}✓ Terraform instalado: $(terraform version | head -n 1)${NC}"

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI no está instalado${NC}"
    echo "Instálalo desde: https://aws.amazon.com/cli/"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI instalado: $(aws --version)${NC}"

# Verificar kubectl (opcional - solo advertencia)
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠ kubectl no está instalado (opcional para despliegue)${NC}"
    echo -e "${YELLOW}  Necesitarás instalarlo después para administrar el cluster${NC}"
    echo -e "${YELLOW}  Descarga: https://kubernetes.io/docs/tasks/tools/${NC}"
    KUBECTL_INSTALLED=false
else
    echo -e "${GREEN}✓ kubectl instalado: $(kubectl version --client --short 2>/dev/null || echo 'kubectl installed')${NC}"
    KUBECTL_INSTALLED=true
fi

# Verificar credenciales AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS credentials no configuradas${NC}"
    echo "Ejecuta: aws configure"
    exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS credentials configuradas (Account: $ACCOUNT_ID)${NC}"

# Verificar archivo terraform.tfvars
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}ERROR: No se encontró terraform.tfvars${NC}"
    exit 1
fi
echo -e "${GREEN}✓ terraform.tfvars encontrado${NC}"

# ====================================
# PASO 2: Inicializar Terraform
# ====================================
show_step "PASO 2/8: Inicializando Terraform"

terraform init

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Terraform inicializado correctamente${NC}"
else
    echo -e "${RED}ERROR: Falló la inicialización de Terraform${NC}"
    exit 1
fi

# ====================================
# PASO 3: Validar configuración
# ====================================
show_step "PASO 3/8: Validando configuración de Terraform"

terraform validate

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Configuración válida${NC}"
else
    echo -e "${RED}ERROR: Configuración inválida${NC}"
    exit 1
fi

# ====================================
# PASO 4: Mostrar plan
# ====================================
show_step "PASO 4/8: Generando plan de despliegue"

terraform plan -out=tfplan

echo ""
echo -e "${YELLOW}¿Deseas continuar con el despliegue?${NC}"
read -p "Escribe 'yes' para continuar: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Despliegue cancelado${NC}"
    rm -f tfplan
    exit 0
fi

# ====================================
# PASO 5: Aplicar infraestructura
# ====================================
show_step "PASO 5/8: Desplegando infraestructura (esto puede tardar 15-20 minutos)"

terraform apply tfplan

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Infraestructura desplegada correctamente${NC}"
    rm -f tfplan
else
    echo -e "${RED}ERROR: Falló el despliegue${NC}"
    rm -f tfplan
    exit 1
fi

# ====================================
# PASO 6: Configurar kubectl (si está instalado)
# ====================================

if [ "$KUBECTL_INSTALLED" = true ]; then
    show_step "PASO 6/8: Configurando kubectl para EKS"

    EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

    aws eks update-kubeconfig \
        --name "$EKS_CLUSTER_NAME" \
        --region "$REGION"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ kubectl configurado para cluster $EKS_CLUSTER_NAME${NC}"
    else
        echo -e "${RED}ERROR: No se pudo configurar kubectl${NC}"
        exit 1
    fi

    # Verificar nodos
    echo ""
    echo -e "${YELLOW}Esperando que los nodos estén listos...${NC}"
    sleep 10

    kubectl get nodes
else
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  PASO 6/8: kubectl no instalado - Saltando configuración${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Puedes instalar kubectl después y ejecutar:${NC}"
    echo -e "  aws eks update-kubeconfig --name \$(terraform output -raw eks_cluster_name) --region $REGION"
    echo ""
fi

# ====================================
# PASO 7: Verificar VPC Link
# ====================================
show_step "PASO 7/8: Verificando VPC Link (puede tardar 5-10 minutos)"

VPC_LINK_ID=$(terraform output -raw api_gateway_vpc_link_id)

echo -e "${YELLOW}Esperando que VPC Link esté disponible...${NC}"

MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    STATUS=$(aws apigateway get-vpc-link --vpc-link-id "$VPC_LINK_ID" --region "$REGION" --query 'status' --output text)
    
    if [ "$STATUS" == "AVAILABLE" ]; then
        echo -e "${GREEN}✓ VPC Link disponible${NC}"
        break
    elif [ "$STATUS" == "FAILED" ]; then
        echo -e "${RED}ERROR: VPC Link falló${NC}"
        exit 1
    else
        echo -e "${YELLOW}VPC Link status: $STATUS (intento $((ATTEMPT+1))/$MAX_ATTEMPTS)${NC}"
        sleep 20
        ATTEMPT=$((ATTEMPT+1))
    fi
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo -e "${RED}ERROR: VPC Link no estuvo disponible después de $((MAX_ATTEMPTS*20)) segundos${NC}"
    exit 1
fi

# ====================================
# PASO 8: Verificar pods (si kubectl está disponible)
# ====================================

if [ "$KUBECTL_INSTALLED" = true ]; then
    show_step "PASO 8/8: Verificando deployments de Kubernetes"

    NAMESPACE=$(terraform output -raw kubernetes_namespace)

    echo -e "${YELLOW}Esperando que los pods estén listos...${NC}"
    sleep 20

    kubectl get pods -n "$NAMESPACE"
    kubectl get services -n "$NAMESPACE"
    kubectl get deployments -n "$NAMESPACE"
else
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  PASO 8/8: kubectl no instalado - Saltando verificación${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Puedes verificar los pods después desde el Bastion Host${NC}"
    echo ""
fi

# ====================================
# RESUMEN FINAL
# ====================================
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              DESPLIEGUE COMPLETADO EXITOSAMENTE              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Obtener outputs importantes
API_URL=$(terraform output -raw api_gateway_url)
BASTION_IP=$(terraform output -raw bastion_public_ip)

echo -e "${CYAN}📋 INFORMACIÓN IMPORTANTE:${NC}"
echo ""
echo -e "${YELLOW}🌐 API Gateway URL:${NC}"
echo "   $API_URL"
echo ""
echo -e "${YELLOW}🔑 API Key:${NC}"
echo "   $(terraform output -raw api_gateway_api_key)"
echo ""
echo -e "${YELLOW}🖥️  Bastion Host:${NC}"
echo "   ssh -i ~/.ssh/microservicios-key.pem ec2-user@$BASTION_IP"
echo ""
echo -e "${YELLOW}☸️  EKS Cluster:${NC}"
echo "   $EKS_CLUSTER_NAME"
echo ""
echo -e "${YELLOW}📦 Namespace:${NC}"
echo "   $NAMESPACE"
echo ""

echo -e "${CYAN}🎯 PRÓXIMOS PASOS:${NC}"
echo ""
echo -e "${GREEN}1.${NC} Verifica que las imágenes Docker estén en ECR:"
echo "   ./2-build-and-push.sh"
echo ""
echo -e "${GREEN}2.${NC} Si las imágenes ya están en ECR, reinicia los deployments:"
echo "   kubectl rollout restart deployment autenticacion -n $NAMESPACE"
echo "   kubectl rollout restart deployment productos -n $NAMESPACE"
echo ""
echo -e "${GREEN}3.${NC} Monitorea el estado de los pods:"
echo "   kubectl get pods -n $NAMESPACE -w"
echo ""
echo -e "${GREEN}4.${NC} Prueba los endpoints:"
echo "   ./4-test-endpoints.sh"
echo ""
echo -e "${GREEN}5.${NC} Ver logs en tiempo real:"
echo "   kubectl logs -f -l app=autenticacion -n $NAMESPACE"
echo "   kubectl logs -f -l app=productos -n $NAMESPACE"
echo ""

echo -e "${CYAN}📊 MONITOREO:${NC}"
echo "   CloudWatch Dashboard: https://console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=$PROJECT_NAME-dashboard"
echo ""

echo -e "${CYAN}🔗 RECURSOS ÚTILES:${NC}"
echo "   Todos los outputs: terraform output"
echo "   API Key: terraform output -raw api_gateway_api_key"
echo "   Comandos útiles: terraform output useful_commands"
echo ""

echo -e "${GREEN}✨ ¡Despliegue completado! ✨${NC}"
echo ""