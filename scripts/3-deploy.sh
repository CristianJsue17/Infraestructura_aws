#!/bin/bash

# Script para desplegar infraestructura ECS Fargate con Terraform
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       DESPLEGAR INFRAESTRUCTURA ECS FARGATE           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Cambiar al directorio de terraform
cd ../terraform

# Verificar que terraform.tfvars existe
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}ERROR: No se encontró terraform.tfvars${NC}"
    echo ""
    echo -e "${YELLOW}Debes crear el archivo terraform.tfvars:${NC}"
    echo "  1. cp terraform.tfvars.example terraform.tfvars"
    echo "  2. Edita terraform.tfvars con tus valores"
    echo ""
    exit 1
fi

echo -e "${YELLOW}Verificando configuración...${NC}"
echo ""

# Mostrar configuración (sin contraseñas)
echo -e "${BLUE}Configuración actual:${NC}"
grep -v "password\|secret" terraform.tfvars | head -20
echo ""

# Confirmar
read -p "¿Deseas continuar con el despliegue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Despliegue cancelado${NC}"
    exit 0
fi

# Paso 1: Terraform Init
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Paso 1/3: Inicializando Terraform${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

terraform init

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Falló la inicialización de Terraform${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Terraform inicializado${NC}"
echo ""

# Paso 2: Terraform Plan
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Paso 2/3: Generando plan de ejecución${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

terraform plan -out=tfplan

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Falló la generación del plan${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Plan generado exitosamente${NC}"
echo ""
echo -e "${YELLOW}Recursos a crear:${NC}"
terraform show -json tfplan | jq -r '.resource_changes[] | select(.change.actions[] | contains("create")) | .address' | wc -l | xargs echo "  Total:"
echo ""

# Confirmar aplicación
read -p "¿Aplicar los cambios? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Aplicación cancelada${NC}"
    rm -f tfplan
    exit 0
fi

# Paso 3: Terraform Apply
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Paso 3/3: Aplicando cambios (esto puede tomar 20-25 min)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

START_TIME=$(date +%s)

terraform apply tfplan

if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         INFRAESTRUCTURA DESPLEGADA EXITOSAMENTE       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Tiempo total: ${MINUTES}m ${SECONDS}s${NC}"
    echo ""
    
    # Mostrar outputs importantes
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  INFORMACIÓN IMPORTANTE${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${BLUE}ECS Cluster:${NC}"
    terraform output -raw ecs_cluster_name
    echo ""
    echo ""
    
    echo -e "${BLUE}API Gateway URL:${NC}"
    terraform output -raw api_gateway_url
    echo ""
    echo ""
    
    echo -e "${BLUE}API Key (guardar en lugar seguro):${NC}"
    terraform output -raw api_gateway_api_key
    echo ""
    echo ""
    
    echo -e "${BLUE}Bastion Host IP:${NC}"
    terraform output -raw bastion_public_ip
    echo ""
    echo ""
    
    # Mostrar próximos pasos
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  PRÓXIMOS PASOS${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "1. Verificar que los servicios ECS están corriendo:"
    echo "   aws ecs list-services --cluster $(terraform output -raw ecs_cluster_name)"
    echo ""
    echo "2. Ver logs en tiempo real:"
    echo "   aws logs tail /ecs/microservicios/autenticacion --follow"
    echo "   aws logs tail /ecs/microservicios/productos --follow"
    echo ""
    echo "3. Probar la API (necesitas la API Key de arriba):"
    echo "   curl -X POST \\"
    echo "     \"$(terraform output -raw api_gateway_url)/api/auth/registrar\" \\"
    echo "     -H \"x-api-key: TU_API_KEY\" \\"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -d '{\"email\":\"test@test.com\",\"password\":\"Test123!\",\"nombre\":\"Test\"}'"
    echo ""
    echo "4. Si actualizas el código de los microservicios:"
    echo "   cd ../scripts && ./4-update-services.sh"
    echo ""
    
    # Limpiar
    rm -f tfplan
else
    echo -e "${RED}ERROR: Falló el despliegue de la infraestructura${NC}"
    echo -e "${YELLOW}Revisa los logs arriba para más detalles${NC}"
    rm -f tfplan
    exit 1
fi