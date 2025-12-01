#1-create-key-pair.sh
#!/bin/bash

# Script para crear Key Pair en AWS
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     CREAR KEY PAIR PARA BASTION HOST - AWS ECS       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Variables
KEY_NAME="microservicios-key"
REGION="us-east-1"
OUTPUT_DIR="$HOME/.ssh"

# Preguntar nombre de la key
read -p "Nombre de la key pair [microservicios-key]: " input_key_name
KEY_NAME=${input_key_name:-$KEY_NAME}

# Preguntar región
read -p "Región de AWS [us-east-1]: " input_region
REGION=${input_region:-$REGION}

echo ""
echo -e "${YELLOW}Configuración:${NC}"
echo "  Key Name: $KEY_NAME"
echo "  Region: $REGION"
echo "  Output Directory: $OUTPUT_DIR"
echo ""

# Confirmar
read -p "¿Continuar? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Operación cancelada${NC}"
    exit 1
fi

# Crear directorio si no existe
mkdir -p "$OUTPUT_DIR"

# Verificar si la key ya existe en AWS
echo -e "${YELLOW}Verificando si la key pair ya existe en AWS...${NC}"
if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" &>/dev/null; then
    echo -e "${RED}ERROR: La key pair '$KEY_NAME' ya existe en AWS${NC}"
    echo ""
    read -p "¿Deseas eliminarla y crear una nueva? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Eliminando key pair existente...${NC}"
        aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION"
        echo -e "${GREEN}✓ Key pair eliminada${NC}"
    else
        echo -e "${RED}Operación cancelada${NC}"
        exit 1
    fi
fi

# Verificar si el archivo local ya existe
if [ -f "$OUTPUT_DIR/$KEY_NAME.pem" ]; then
    echo -e "${YELLOW}ADVERTENCIA: El archivo $OUTPUT_DIR/$KEY_NAME.pem ya existe localmente${NC}"
    read -p "¿Deseas sobrescribirlo? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operación cancelada${NC}"
        exit 1
    fi
    rm -f "$OUTPUT_DIR/$KEY_NAME.pem"
fi

# Crear la key pair
echo -e "${YELLOW}Creando key pair en AWS...${NC}"
aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --query 'KeyMaterial' \
    --output text > "$OUTPUT_DIR/$KEY_NAME.pem"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Key pair creada exitosamente${NC}"
else
    echo -e "${RED}ERROR: No se pudo crear la key pair${NC}"
    exit 1
fi

# Cambiar permisos
chmod 400 "$OUTPUT_DIR/$KEY_NAME.pem"
echo -e "${GREEN}✓ Permisos establecidos (400)${NC}"

# Resumen
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              KEY PAIR CREADA EXITOSAMENTE             ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Detalles:${NC}"
echo "  Nombre: $KEY_NAME"
echo "  Región: $REGION"
echo "  Archivo: $OUTPUT_DIR/$KEY_NAME.pem"
echo ""
echo -e "${YELLOW}IMPORTANTE:${NC}"
echo "  1. Guarda el archivo $KEY_NAME.pem en un lugar seguro"
echo "  2. NO compartas esta key con nadie"
echo "  3. NO subas esta key a GitHub"
echo ""
echo -e "${GREEN}Próximos pasos:${NC}"
echo "  1. Actualiza terraform.tfvars con:"
echo "     bastion_key_name = \"$KEY_NAME\""
echo ""
echo "  2. Para conectar al bastion después del despliegue:"
echo "     ssh -i $OUTPUT_DIR/$KEY_NAME.pem ec2-user@BASTION_IP"
echo ""