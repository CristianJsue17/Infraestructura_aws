#!/bin/bash

# Script para destruir toda la infraestructura ECS Fargate
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║       DESTRUIR TODA LA INFRAESTRUCTURA - AWS          ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${RED}⚠️  ADVERTENCIA ⚠️${NC}"
echo -e "${RED}Esta acción eliminará TODA la infraestructura:${NC}"
echo "  - ECS Cluster y todos los servicios/tasks"
echo "  - Bases de datos RDS (se crearán snapshots finales)"
echo "  - VPC, Subnets, Security Groups"
echo "  - Application Load Balancer"
echo "  - API Gateway"
echo "  - Bastion Host"
echo "  - CloudWatch Logs"
echo "  - Repositorios ECR (las imágenes se eliminarán)"
echo "  - Secrets Manager"
echo ""

read -p "¿Estás COMPLETAMENTE seguro? Escribe 'DESTRUIR' para confirmar: " confirmation

if [ "$confirmation" != "DESTRUIR" ]; then
    echo -e "${GREEN}Operación cancelada. Tu infraestructura está a salvo.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Última oportunidad para cancelar...${NC}"
sleep 3
echo ""

cd ../terraform

# Verificar que terraform.tfstate existe
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}No se encontró terraform.tfstate${NC}"
    echo "Es posible que no haya infraestructura desplegada."
    read -p "¿Continuar de todos modos? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Obtener información de ECR
REGION=$(grep 'aws_region' terraform.tfvars | cut -d '"' -f 2 2>/dev/null || echo "us-east-1")
PROJECT_NAME=$(grep 'project_name' terraform.tfvars | cut -d '"' -f 2 2>/dev/null || echo "microservicios")

# Eliminar imágenes de ECR (opcional)
echo -e "${YELLOW}[1/3] Limpiando repositorios ECR...${NC}"
echo ""

read -p "¿Deseas eliminar también las imágenes de ECR? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Eliminando imágenes de ECR...${NC}"
    
    # Autenticación
    echo "  - Eliminando imágenes de autenticación..."
    aws ecr batch-delete-image \
        --repository-name "$PROJECT_NAME/autenticacion" \
        --region "$REGION" \
        --image-ids "$(aws ecr list-images --repository-name "$PROJECT_NAME/autenticacion" --region "$REGION" --query 'imageIds[*]' --output json)" \
        2>/dev/null || echo "    No hay imágenes de autenticación"
    
    # Productos
    echo "  - Eliminando imágenes de productos..."
    aws ecr batch-delete-image \
        --repository-name "$PROJECT_NAME/productos" \
        --region "$REGION" \
        --image-ids "$(aws ecr list-images --repository-name "$PROJECT_NAME/productos" --region "$REGION" --query 'imageIds[*]' --output json)" \
        2>/dev/null || echo "    No hay imágenes de productos"
    
    echo -e "${GREEN}✓ Imágenes ECR eliminadas${NC}"
else
    echo -e "${YELLOW}Imágenes ECR conservadas (se eliminarán los repositorios pero no las imágenes)${NC}"
fi

echo ""

# Destruir infraestructura con Terraform
echo -e "${YELLOW}[2/3] Destruyendo infraestructura con Terraform...${NC}"
echo ""
echo -e "${RED}Esto puede tomar 10-15 minutos...${NC}"
echo ""

START_TIME=$(date +%s)

terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo ""
    echo -e "${GREEN}✓ Infraestructura destruida (${MINUTES}m ${SECONDS}s)${NC}"
else
    echo -e "${RED}ERROR: Algunos recursos no pudieron ser eliminados${NC}"
    echo -e "${YELLOW}Revisa manualmente la consola de AWS${NC}"
fi

echo ""

# Limpiar archivos locales
echo -e "${YELLOW}[3/3] Limpiando archivos locales...${NC}"
echo ""

read -p "¿Deseas eliminar archivos de estado de Terraform? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f terraform.tfstate*
    rm -rf .terraform
    rm -f .terraform.lock.hcl
    rm -f tfplan
    echo -e "${GREEN}✓ Archivos de Terraform eliminados${NC}"
else
    echo -e "${YELLOW}Archivos de Terraform conservados${NC}"
fi

echo ""

# Resumen final
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         INFRAESTRUCTURA DESTRUIDA EXITOSAMENTE        ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Recursos eliminados:${NC}"
echo "  ✓ ECS Cluster y servicios"
echo "  ✓ Bases de datos RDS"
echo "  ✓ VPC y componentes de red"
echo "  ✓ Application Load Balancer"
echo "  ✓ API Gateway"
echo "  ✓ Bastion Host"
echo "  ✓ CloudWatch Logs"
echo "  ✓ Repositorios ECR"
echo "  ✓ Secrets Manager"
echo ""
echo -e "${YELLOW}IMPORTANTE:${NC}"
echo "  - Verifica en la consola de AWS que no queden recursos huérfanos"
echo "  - Los snapshots de RDS se conservan por seguridad"
echo "  - Los logs de CloudWatch pueden tardar en eliminarse completamente"
echo "  - Si quedan recursos, elimínalos manualmente desde la consola"
echo ""
echo -e "${BLUE}Para volver a desplegar:${NC}"
echo "  1. cd scripts"
echo "  2. ./2-build-and-push.sh"
echo "  3. ./3-deploy.sh"
echo ""