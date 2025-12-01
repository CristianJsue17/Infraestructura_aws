#2-build-and-push.sh
#!/bin/bash

# Script para CLONAR de GitHub, construir y subir imágenes Docker a ECR
set -e

# ====================================
# ⚠️ CONFIGURAR AQUÍ TUS REPOS DE GITHUB
# ====================================
GITHUB_REPO_AUTENTICACION="https://github.com/Treffy10/microservicio-usuario-ejemplo.git"
GITHUB_REPO_PRODUCTOS="https://github.com/CristianJsue17/productos.git"
# ====================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   CLONE, BUILD & PUSH DOCKER IMAGES FROM GITHUB      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Variables
REGION="us-east-1"
PROJECT_NAME="microservicios"
WORK_DIR="/tmp/docker-build-$$"

echo -e "${YELLOW}Repositorios configurados:${NC}"
echo "  Autenticación: $GITHUB_REPO_AUTENTICACION"
echo "  Productos: $GITHUB_REPO_PRODUCTOS"
echo ""

# Verificar que git está instalado
if ! command -v git &> /dev/null; then
    echo -e "${RED}ERROR: Git no está instalado${NC}"
    echo "Instálalo con: sudo apt-get install git"
    exit 1
fi

# Obtener Account ID
echo -e "${YELLOW}Obteniendo AWS Account ID...${NC}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ Account ID: $ACCOUNT_ID${NC}"
echo ""

# ECR Repositories
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
ECR_AUTENTICACION="$ECR_REGISTRY/$PROJECT_NAME/autenticacion"
ECR_PRODUCTOS="$ECR_REGISTRY/$PROJECT_NAME/productos"

# Login a ECR
echo -e "${YELLOW}Haciendo login en ECR...${NC}"
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Login exitoso en ECR${NC}"
else
    echo -e "${RED}ERROR: No se pudo hacer login en ECR${NC}"
    exit 1
fi
echo ""

# Crear directorio temporal de trabajo
echo -e "${YELLOW}Creando directorio temporal: $WORK_DIR${NC}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"
echo -e "${GREEN}✓ Directorio creado${NC}"
echo ""

# Función para clonar, construir y pushear
clone_build_push() {
    local SERVICE_NAME=$1
    local GITHUB_URL=$2
    local ECR_REPO=$3
    local DOCKERFILE="Dockerfile.prod"
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Procesando: $SERVICE_NAME${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    
    # Clonar repositorio
    echo -e "${YELLOW}1/4 Clonando repositorio de GitHub...${NC}"
    if [ -d "$SERVICE_NAME" ]; then
        echo -e "${YELLOW}Directorio ya existe, eliminando...${NC}"
        rm -rf "$SERVICE_NAME"
    fi
    
    git clone "$GITHUB_URL" "$SERVICE_NAME"
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: No se pudo clonar el repositorio${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Repositorio clonado${NC}"
    echo ""
    
    cd "$SERVICE_NAME"
    
    # Verificar que existe el Dockerfile
    echo -e "${YELLOW}2/4 Verificando Dockerfile...${NC}"
    if [ ! -f "$DOCKERFILE" ]; then
        echo -e "${RED}ERROR: No se encontró $DOCKERFILE${NC}"
        cd ..
        return 1
    fi
    echo -e "${GREEN}✓ Dockerfile encontrado${NC}"
    echo ""
    
    # Construir imagen
    echo -e "${YELLOW}3/4 Construyendo imagen Docker...${NC}"
    docker build -f "$DOCKERFILE" -t "$SERVICE_NAME:latest" .
    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Falló la construcción de la imagen${NC}"
        cd ..
        return 1
    fi
    echo -e "${GREEN}✓ Imagen construida${NC}"
    echo ""
    
    # Etiquetar imagen
    echo -e "${YELLOW}4/4 Etiquetando y subiendo a ECR...${NC}"
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    docker tag "$SERVICE_NAME:latest" "$ECR_REPO:latest"
    docker tag "$SERVICE_NAME:latest" "$ECR_REPO:$TIMESTAMP"
    echo -e "${GREEN}✓ Imagen etiquetada${NC}"
    
    # Push imagen
    docker push "$ECR_REPO:latest"
    docker push "$ECR_REPO:$TIMESTAMP"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Imagen subida exitosamente a ECR${NC}"
    else
        echo -e "${RED}ERROR: No se pudo subir la imagen${NC}"
        cd ..
        return 1
    fi
    
    cd ..
    echo ""
}

# Confirmar antes de continuar
echo -e "${YELLOW}Este script va a:${NC}"
echo "  1. Clonar los repositorios de GitHub"
echo "  2. Construir las imágenes Docker"
echo "  3. Subirlas a ECR"
echo ""
read -p "¿Continuar? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Operación cancelada${NC}"
    rm -rf "$WORK_DIR"
    exit 0
fi
echo ""

# Procesar Autenticación
clone_build_push \
    "autenticacion" \
    "$GITHUB_REPO_AUTENTICACION" \
    "$ECR_AUTENTICACION"

# Procesar Productos
clone_build_push \
    "productos" \
    "$GITHUB_REPO_PRODUCTOS" \
    "$ECR_PRODUCTOS"

# Limpiar directorio temporal
echo -e "${YELLOW}Limpiando archivos temporales...${NC}"
cd /tmp
rm -rf "$WORK_DIR"
echo -e "${GREEN}✓ Archivos temporales eliminados${NC}"
echo ""

# Resumen
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          IMÁGENES SUBIDAS EXITOSAMENTE A ECR          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Imágenes disponibles en ECR:${NC}"
echo "  Autenticación: $ECR_AUTENTICACION:latest"
echo "  Productos: $ECR_PRODUCTOS:latest"
echo ""
echo -e "${YELLOW}Próximo paso:${NC}"
echo "  Ejecuta: cd ../scripts && ./3-deploy.sh"
echo ""