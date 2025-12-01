#!/bin/bash

# ============================================================================
# SCRIPT DE DIAGNÓSTICO DESDE BASTION (DENTRO DEL VPC)
# Ejecutar este script desde el bastion host para pruebas de conectividad
# ============================================================================

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     DIAGNÓSTICO DE CONECTIVIDAD INTERNA (DESDE BASTION)     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verificar que estamos en el bastion
if ! grep -q "ubuntu" /etc/hostname 2>/dev/null; then
    echo -e "${YELLOW}⚠️  ADVERTENCIA: Este script debe ejecutarse desde el bastion host${NC}"
    echo ""
fi

# Variables (ajustar según tu infraestructura)
NLB_DNS="microservicios-nlb-c035dc9a1f13e7bc.elb.us-east-1.amazonaws.com"
RDS_AUTH_ENDPOINT="microservicios-autenticacion-db.cineegcoaj4u.us-east-1.rds.amazonaws.com"
RDS_PROD_ENDPOINT="microservicios-productos-db.cineegcoaj4u.us-east-1.rds.amazonaws.com"

# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "1️⃣  PRUEBAS DE CONECTIVIDAD TCP - NLB"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "🧪 Probando NLB Listener puerto 8000 (autenticación)..."
if timeout 5 bash -c "cat < /dev/tcp/$NLB_DNS/8000" 2>/dev/null; then
    echo -e "   ${GREEN}✅ Puerto 8000 responde${NC}"
else
    echo -e "   ${RED}❌ Puerto 8000 NO responde${NC}"
fi

echo ""
echo "🧪 Probando NLB Listener puerto 8080 (productos)..."
if timeout 5 bash -c "cat < /dev/tcp/$NLB_DNS/8080" 2>/dev/null; then
    echo -e "   ${GREEN}✅ Puerto 8080 responde${NC}"
else
    echo -e "   ${RED}❌ Puerto 8080 NO responde${NC}"
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "2️⃣  PRUEBAS DE CONECTIVIDAD TCP - RDS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "🧪 Probando RDS Autenticación puerto 5432..."
if timeout 5 bash -c "cat < /dev/tcp/$RDS_AUTH_ENDPOINT/5432" 2>/dev/null; then
    echo -e "   ${GREEN}✅ RDS Autenticación accesible${NC}"
else
    echo -e "   ${RED}❌ RDS Autenticación NO accesible${NC}"
fi

echo ""
echo "🧪 Probando RDS Productos puerto 5432..."
if timeout 5 bash -c "cat < /dev/tcp/$RDS_PROD_ENDPOINT/5432" 2>/dev/null; then
    echo -e "   ${GREEN}✅ RDS Productos accesible${NC}"
else
    echo -e "   ${RED}❌ RDS Productos NO accesible${NC}"
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "3️⃣  PRUEBAS HTTP - NLB (LISTENERS)"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "🧪 GET http://$NLB_DNS:8000/api/auth/health"
HEALTH_AUTH=$(curl -s -w "\nHTTP_CODE:%{http_code}" "http://$NLB_DNS:8000/api/auth/health" 2>/dev/null)
HTTP_CODE=$(echo "$HEALTH_AUTH" | grep HTTP_CODE | cut -d: -f2)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "   ${GREEN}✅ Autenticación respondiendo (HTTP $HTTP_CODE)${NC}"
    echo "$HEALTH_AUTH" | grep -v HTTP_CODE
elif [ "$HTTP_CODE" == "404" ]; then
    echo -e "   ${YELLOW}⚠️  Endpoint /health no existe (HTTP $HTTP_CODE), pero el servicio responde${NC}"
else
    echo -e "   ${RED}❌ Error (HTTP $HTTP_CODE)${NC}"
fi

echo ""
echo "🧪 POST http://$NLB_DNS:8000/api/auth/registrar"
REGISTER_TEST=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -X POST "http://$NLB_DNS:8000/api/auth/registrar" \
    -H "Content-Type: application/json" \
    -d '{
        "nombre_usuario": "bastiontest_'$(date +%s)'",
        "email": "bastiontest'$(date +%s)'@example.com",
        "nombre_completo": "Bastion Test",
        "contrasena": "test123456",
        "es_admin": false
    }')

HTTP_CODE=$(echo "$REGISTER_TEST" | grep HTTP_CODE | cut -d: -f2)

if [ "$HTTP_CODE" == "201" ]; then
    echo -e "   ${GREEN}✅ Registro funcionando (HTTP $HTTP_CODE)${NC}"
    echo "$REGISTER_TEST" | grep -v HTTP_CODE | head -1
elif [ "$HTTP_CODE" == "422" ]; then
    echo -e "   ${YELLOW}⚠️  Validación fallida (HTTP $HTTP_CODE) - normal si el usuario ya existe${NC}"
else
    echo -e "   ${RED}❌ Error (HTTP $HTTP_CODE)${NC}"
fi

echo ""
echo "🧪 GET http://$NLB_DNS:8080/api/productos"
PRODUCTOS_LIST=$(curl -s -w "\nHTTP_CODE:%{http_code}" "http://$NLB_DNS:8080/api/productos" 2>/dev/null)
HTTP_CODE=$(echo "$PRODUCTOS_LIST" | grep HTTP_CODE | cut -d: -f2)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "   ${GREEN}✅ Productos respondiendo (HTTP $HTTP_CODE)${NC}"
    echo "$PRODUCTOS_LIST" | grep -v HTTP_CODE | head -1
elif [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "403" ]; then
    echo -e "   ${YELLOW}⚠️  Requiere autenticación (HTTP $HTTP_CODE) - esto es normal${NC}"
else
    echo -e "   ${RED}❌ Error (HTTP $HTTP_CODE)${NC}"
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "4️⃣  RESOLUCIÓN DNS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

echo "🔍 Resolviendo NLB DNS..."
NLB_IPS=$(dig +short $NLB_DNS 2>/dev/null || nslookup $NLB_DNS 2>/dev/null | grep Address | tail -n +2 | awk '{print $2}')

if [ -n "$NLB_IPS" ]; then
    echo -e "${GREEN}✅ NLB DNS resuelve a:${NC}"
    echo "$NLB_IPS" | while read ip; do
        echo "   • $ip"
    done
else
    echo -e "${RED}❌ No se pudo resolver NLB DNS${NC}"
fi

echo ""
echo "🔍 Resolviendo RDS Autenticación..."
RDS_AUTH_IP=$(dig +short $RDS_AUTH_ENDPOINT 2>/dev/null | head -1 || nslookup $RDS_AUTH_ENDPOINT 2>/dev/null | grep Address | tail -1 | awk '{print $2}')

if [ -n "$RDS_AUTH_IP" ]; then
    echo -e "${GREEN}✅ RDS Autenticación resuelve a: $RDS_AUTH_IP${NC}"
else
    echo -e "${RED}❌ No se pudo resolver RDS Autenticación${NC}"
fi

echo ""
echo "🔍 Resolviendo RDS Productos..."
RDS_PROD_IP=$(dig +short $RDS_PROD_ENDPOINT 2>/dev/null | head -1 || nslookup $RDS_PROD_ENDPOINT 2>/dev/null | grep Address | tail -1 | awk '{print $2}')

if [ -n "$RDS_PROD_IP" ]; then
    echo -e "${GREEN}✅ RDS Productos resuelve a: $RDS_PROD_IP${NC}"
else
    echo -e "${RED}❌ No se pudo resolver RDS Productos${NC}"
fi

# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     RESUMEN DE CONECTIVIDAD                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${BLUE}📊 Estado de Conectividad Interna:${NC}"
echo ""
echo "  Si todos los checks están ✅, significa que:"
echo "    • Los pods pueden comunicarse con RDS"
echo "    • El NLB puede alcanzar los pods"
echo "    • Los servicios están respondiendo correctamente"
echo ""
echo "  Los ❌ indican problemas de red o configuración que"
echo "  requieren revisión de Security Groups o configuración de servicios."
echo ""