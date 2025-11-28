#!/bin/bash

# Script para actualizar servicios ECS Fargate (force new deployment)
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ACTUALIZAR SERVICIOS ECS FARGATE             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Obtener información de Terraform
cd ../terraform

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}ERROR: No se encontró terraform.tfstate${NC}"
    echo "Debes ejecutar './3-deploy.sh' primero"
    exit 1
fi

CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null)
SERVICE_AUTH=$(terraform output -raw ecs_autenticacion_service_name 2>/dev/null)
SERVICE_PROD=$(terraform output -raw ecs_productos_service_name 2>/dev/null)
REGION=$(terraform output -raw aws_region 2>/dev/null)

if [ -z "$CLUSTER_NAME" ] || [ -z "$SERVICE_AUTH" ] || [ -z "$SERVICE_PROD" ]; then
    echo -e "${RED}ERROR: No se pudieron obtener los nombres de los servicios${NC}"
    exit 1
fi

echo -e "${YELLOW}Información de servicios:${NC}"
echo "  Cluster: $CLUSTER_NAME"
echo "  Región: $REGION"
echo "  Servicio Autenticación: $SERVICE_AUTH"
echo "  Servicio Productos: $SERVICE_PROD"
echo ""

echo -e "${BLUE}Este script fuerza un nuevo despliegue de los servicios ECS.${NC}"
echo -e "${BLUE}Las nuevas tasks usarán las últimas imágenes de ECR con tag 'latest'.${NC}"
echo ""

read -p "¿Continuar? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operación cancelada${NC}"
    exit 0
fi

# Función para actualizar un servicio
update_service() {
    local SERVICE_NAME=$1
    local DISPLAY_NAME=$2
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Actualizando: $DISPLAY_NAME${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}Forzando nuevo despliegue...${NC}"
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --force-new-deployment \
        --region "$REGION" \
        --query 'service.serviceName' \
        --output text
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Despliegue iniciado para $DISPLAY_NAME${NC}"
    else
        echo -e "${RED}ERROR: No se pudo actualizar $DISPLAY_NAME${NC}"
        return 1
    fi
}

# Actualizar servicio de Autenticación
update_service "$SERVICE_AUTH" "Autenticación"

# Esperar un momento entre actualizaciones
sleep 2

# Actualizar servicio de Productos
update_service "$SERVICE_PROD" "Productos"

# Mostrar estado de los servicios
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Estado de los servicios${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Autenticación:${NC}"
aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_AUTH" \
    --region "$REGION" \
    --query 'services[0].[serviceName,runningCount,desiredCount,status,deployments[0].status]' \
    --output text

echo ""
echo -e "${YELLOW}Productos:${NC}"
aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_PROD" \
    --region "$REGION" \
    --query 'services[0].[serviceName,runningCount,desiredCount,status,deployments[0].status]' \
    --output text

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            SERVICIOS ACTUALIZADOS EXITOSAMENTE        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Próximos pasos:${NC}"
echo ""
echo "1. Monitorear el despliegue:"
echo "   aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_AUTH $SERVICE_PROD"
echo ""
echo "2. Ver logs de las nuevas tasks:"
echo "   aws logs tail /ecs/microservicios/autenticacion --follow --region $REGION"
echo "   aws logs tail /ecs/microservicios/productos --follow --region $REGION"
echo ""
echo "3. Listar tasks en ejecución:"
echo "   aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_AUTH"
echo "   aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_PROD"
echo ""
echo -e "${BLUE}Nota: El despliegue puede tomar 2-5 minutos.${NC}"
echo -e "${BLUE}Las nuevas tasks reemplazarán gradualmente a las antiguas.${NC}"
echo ""