#!/bin/bash

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     DIAGNÓSTICO COMPLETO DE MICROSERVICIOS - CORREGIDO       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detectar cluster
CLUSTER_NAME=$(aws eks list-clusters --query 'clusters[0]' --output text)
echo "🎯 Cluster detectado: $CLUSTER_NAME"

# Actualizar kubeconfig
aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1 >/dev/null 2>&1

# Variables dinámicas
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.resourcesVpcConfig.vpcId' --output text)
EKS_CLUSTER_SG=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
NLB_DNS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `microservicios`)].DNSName' --output text)

echo "📦 VPC ID: $VPC_ID"
echo "🔒 EKS Cluster SG: $EKS_CLUSTER_SG"
echo "⚖️  NLB DNS: $NLB_DNS"
echo ""

# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "1️⃣  ESTADO DE PODS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

AUTH_RUNNING=$(kubectl get pods -n microservicios -l app=autenticacion --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
PROD_RUNNING=$(kubectl get pods -n microservicios -l app=productos --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

kubectl get pods -n microservicios -o wide

echo ""
if [ "$AUTH_RUNNING" -ge 1 ] && [ "$PROD_RUNNING" -ge 1 ]; then
    echo -e "${GREEN}✅ Pods funcionando: ${AUTH_RUNNING} autenticación, ${PROD_RUNNING} productos${NC}"
else
    echo -e "${RED}❌ Algunos pods no están Running${NC}"
    echo ""
    echo "Logs de autenticación:"
    kubectl logs -l app=autenticacion -n microservicios --tail=10
    echo ""
    echo "Logs de productos:"
    kubectl logs -l app=productos -n microservicios --tail=10
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "2️⃣  CONFIGURACIÓN DE SECURITY GROUPS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Obtener nodos
NODE_IDS=($(kubectl get nodes -o jsonpath='{.items[*].spec.providerID}' | sed 's|.*\/||g'))

echo "Nodos EKS: ${#NODE_IDS[@]}"
if [ ${#NODE_IDS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No se encontraron nodos${NC}"
else
    # Obtener Security Groups del primer nodo
    NODE_SG=$(aws ec2 describe-instances --instance-ids ${NODE_IDS[0]} --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' --output text)
    
    echo ""
    echo "Security Groups de nodos:"
    for SG in $NODE_SG; do
        SG_NAME=$(aws ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].GroupName' --output text)
        echo "  📋 $SG ($SG_NAME)"
        
        # Verificar reglas para NodePorts
        NODEPORT_RULES=$(aws ec2 describe-security-groups --group-ids $SG \
            --query "SecurityGroups[0].IpPermissions[?FromPort<=\`30081\` && ToPort>=\`30080\`]" \
            --output json)
        
        if echo "$NODEPORT_RULES" | grep -q "30080"; then
            echo -e "     ${GREEN}✅ Permite NodePorts 30080-30081${NC}"
        else
            echo -e "     ${YELLOW}⚠️  No tiene regla para NodePorts${NC}"
        fi
    done
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "3️⃣  CONFIGURACIÓN DE RDS SECURITY GROUPS"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# RDS Productos
RDS_PROD_SG=$(aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier, `productos`)].VpcSecurityGroups[0].VpcSecurityGroupId' \
    --output text)

RDS_PROD_ENDPOINT=$(aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier, `productos`)].Endpoint.Address' \
    --output text)

# RDS Autenticación
RDS_AUTH_SG=$(aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier, `autenticacion`)].VpcSecurityGroups[0].VpcSecurityGroupId' \
    --output text)

RDS_AUTH_ENDPOINT=$(aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier, `autenticacion`)].Endpoint.Address' \
    --output text)

echo "📊 RDS Productos:"
echo "   Endpoint: $RDS_PROD_ENDPOINT"
echo "   SG: $RDS_PROD_SG"

# Verificar reglas de RDS Productos
RDS_PROD_RULES=$(aws ec2 describe-security-groups --group-ids $RDS_PROD_SG \
    --query "SecurityGroups[0].IpPermissions[?ToPort==\`5432\`]" --output json)

if echo "$RDS_PROD_RULES" | grep -q "$EKS_CLUSTER_SG"; then
    echo -e "   ${GREEN}✅ Security Group permite EKS Cluster SG${NC}"
else
    echo -e "   ${YELLOW}⚠️  No permite EKS Cluster SG directamente${NC}"
fi

echo ""
echo "📊 RDS Autenticación:"
echo "   Endpoint: $RDS_AUTH_ENDPOINT"
echo "   SG: $RDS_AUTH_SG"

# Verificar reglas de RDS Autenticación
RDS_AUTH_RULES=$(aws ec2 describe-security-groups --group-ids $RDS_AUTH_SG \
    --query "SecurityGroups[0].IpPermissions[?ToPort==\`5432\`]" --output json)

if echo "$RDS_AUTH_RULES" | grep -q "$EKS_CLUSTER_SG"; then
    echo -e "   ${GREEN}✅ Security Group permite EKS Cluster SG${NC}"
else
    echo -e "   ${YELLOW}⚠️  No permite EKS Cluster SG directamente${NC}"
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "4️⃣  TARGET GROUPS DEL NLB"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Target Group Autenticación
AUTH_TG_ARN=$(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?contains(TargetGroupName, `auth`)].TargetGroupArn' \
    --output text)

echo "🎯 Target Group Autenticación:"
AUTH_HEALTH=$(aws elbv2 describe-target-health --target-group-arn $AUTH_TG_ARN \
    --query 'TargetHealthDescriptions[*].[Target.Id, TargetHealth.State]' \
    --output text)

HEALTHY_AUTH=$(echo "$AUTH_HEALTH" | grep -c "healthy")
TOTAL_AUTH=$(echo "$AUTH_HEALTH" | wc -l)

if [ $HEALTHY_AUTH -eq $TOTAL_AUTH ] && [ $TOTAL_AUTH -gt 0 ]; then
    echo -e "   ${GREEN}✅ $HEALTHY_AUTH/$TOTAL_AUTH targets healthy${NC}"
else
    echo -e "   ${RED}❌ Solo $HEALTHY_AUTH/$TOTAL_AUTH targets healthy${NC}"
fi

aws elbv2 describe-target-health --target-group-arn $AUTH_TG_ARN \
    --query 'TargetHealthDescriptions[*].[Target.Id, TargetHealth.State, TargetHealth.Reason]' \
    --output table

# Target Group Productos
PROD_TG_ARN=$(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?contains(TargetGroupName, `prod`)].TargetGroupArn' \
    --output text)

echo ""
echo "🎯 Target Group Productos:"
PROD_HEALTH=$(aws elbv2 describe-target-health --target-group-arn $PROD_TG_ARN \
    --query 'TargetHealthDescriptions[*].[Target.Id, TargetHealth.State]' \
    --output text)

HEALTHY_PROD=$(echo "$PROD_HEALTH" | grep -c "healthy")
TOTAL_PROD=$(echo "$PROD_HEALTH" | wc -l)

if [ $HEALTHY_PROD -eq $TOTAL_PROD ] && [ $TOTAL_PROD -gt 0 ]; then
    echo -e "   ${GREEN}✅ $HEALTHY_PROD/$TOTAL_PROD targets healthy${NC}"
else
    echo -e "   ${RED}❌ Solo $HEALTHY_PROD/$TOTAL_PROD targets healthy${NC}"
fi

aws elbv2 describe-target-health --target-group-arn $PROD_TG_ARN \
    --query 'TargetHealthDescriptions[*].[Target.Id, TargetHealth.State, TargetHealth.Reason]' \
    --output table

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "5️⃣  API GATEWAY Y VPC LINK"
echo "═══════════════════════════════════════════════════════════════"
echo ""

API_ID=$(aws apigateway get-rest-apis --query 'items[?name==`microservicios-api`].id' --output text)
VPC_LINK_ID=$(aws apigateway get-vpc-links --query 'items[0].id' --output text)
VPC_LINK_STATUS=$(aws apigateway get-vpc-links --query 'items[0].status' --output text)

echo "🌐 API Gateway ID: $API_ID"
echo "🔗 VPC Link ID: $VPC_LINK_ID"
echo "📊 VPC Link Status: $VPC_LINK_STATUS"

if [ "$VPC_LINK_STATUS" == "AVAILABLE" ]; then
    echo -e "   ${GREEN}✅ VPC Link disponible${NC}"
else
    echo -e "   ${RED}❌ VPC Link NO disponible${NC}"
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "6️⃣  PRUEBA DE ENDPOINTS DE API GATEWAY"
echo "═══════════════════════════════════════════════════════════════"
echo ""

API_URL="https://${API_ID}.execute-api.us-east-1.amazonaws.com/prod"
API_KEY="0XXNnq9gWl380yexIzU5S4teqWuGc8gX6F0UIy8F"

echo "🧪 Probando endpoint de registro..."
REGISTER_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -X POST "${API_URL}/api/auth/registrar" \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "nombre_usuario": "diagtest_'$(date +%s)'",
    "email": "diagtest'$(date +%s)'@example.com",
    "nombre_completo": "Diagnostic Test",
    "contrasena": "test123456",
    "es_admin": false
  }')

HTTP_CODE=$(echo "$REGISTER_RESPONSE" | grep HTTP_CODE | cut -d: -f2)

if [ "$HTTP_CODE" == "201" ]; then
    echo -e "   ${GREEN}✅ POST /api/auth/registrar → HTTP $HTTP_CODE${NC}"
else
    echo -e "   ${RED}❌ POST /api/auth/registrar → HTTP $HTTP_CODE${NC}"
    echo "$REGISTER_RESPONSE" | grep -v HTTP_CODE
fi

echo ""
echo "🧪 Probando endpoint de login..."
LOGIN_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -X POST "${API_URL}/api/auth/login" \
  -H "x-api-key: ${API_KEY}" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=diagtest_$(date +%s)&password=wrongpassword")

HTTP_CODE=$(echo "$LOGIN_RESPONSE" | grep HTTP_CODE | cut -d: -f2)

if [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "200" ]; then
    echo -e "   ${GREEN}✅ POST /api/auth/login → HTTP $HTTP_CODE (endpoint funciona)${NC}"
else
    echo -e "   ${YELLOW}⚠️  POST /api/auth/login → HTTP $HTTP_CODE${NC}"
fi

echo ""
echo "🧪 Probando endpoint de verificación (GET)..."
VERIFY_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
  -X GET "${API_URL}/api/auth/verificar?token=fake_token" \
  -H "x-api-key: ${API_KEY}")

HTTP_CODE=$(echo "$VERIFY_RESPONSE" | grep HTTP_CODE | cut -d: -f2)

if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "422" ] || [ "$HTTP_CODE" == "401" ]; then
    echo -e "   ${GREEN}✅ GET /api/auth/verificar → HTTP $HTTP_CODE (endpoint funciona)${NC}"
    echo "      Nota: 422/401 es normal sin token válido, lo importante es que NO sea 405"
elif [ "$HTTP_CODE" == "405" ]; then
    echo -e "   ${RED}❌ GET /api/auth/verificar → HTTP 405 Method Not Allowed${NC}"
    echo "      El método GET no está configurado correctamente"
else
    echo -e "   ${YELLOW}⚠️  GET /api/auth/verificar → HTTP $HTTP_CODE${NC}"
fi

# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     RESUMEN DEL DIAGNÓSTICO                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Calcular puntuación
SCORE=0
MAX_SCORE=5

# 1. Pods running
if [ "$AUTH_RUNNING" -ge 1 ] && [ "$PROD_RUNNING" -ge 1 ]; then
    SCORE=$((SCORE + 1))
fi

# 2. Target Groups healthy
if [ $HEALTHY_AUTH -eq $TOTAL_AUTH ] && [ $TOTAL_AUTH -gt 0 ]; then
    SCORE=$((SCORE + 1))
fi

if [ $HEALTHY_PROD -eq $TOTAL_PROD ] && [ $TOTAL_PROD -gt 0 ]; then
    SCORE=$((SCORE + 1))
fi

# 3. VPC Link available
if [ "$VPC_LINK_STATUS" == "AVAILABLE" ]; then
    SCORE=$((SCORE + 1))
fi

# 4. API funcionando
if [ "$HTTP_CODE" != "405" ]; then
    SCORE=$((SCORE + 1))
fi

if [ $SCORE -eq $MAX_SCORE ]; then
    echo -e "${GREEN}✅ SISTEMA FUNCIONANDO CORRECTAMENTE ($SCORE/$MAX_SCORE checks)${NC}"
    echo ""
    echo "Todos los componentes están operativos:"
    echo "  • Pods en ejecución"
    echo "  • Target Groups healthy"
    echo "  • VPC Link disponible"
    echo "  • API Gateway respondiendo"
elif [ $SCORE -ge 3 ]; then
    echo -e "${YELLOW}⚠️  SISTEMA MAYORMENTE FUNCIONAL ($SCORE/$MAX_SCORE checks)${NC}"
    echo ""
    echo "La mayoría de componentes funcionan, pero hay algunos warnings."
else
    echo -e "${RED}❌ SISTEMA CON PROBLEMAS ($SCORE/$MAX_SCORE checks)${NC}"
    echo ""
    echo "Hay problemas significativos que requieren atención."
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}💡 NOTA IMPORTANTE:${NC}"
echo "Este script NO puede probar conectividad TCP directa al NLB o RDS"
echo "porque se ejecuta desde fuera del VPC."
echo ""
echo "Para pruebas de conectividad detalladas, ejecuta desde el bastion:"
echo "  ssh -i ~/.ssh/microservicios-key.pem ubuntu@BASTION_IP"
echo "  curl http://NLB_DNS:8000/api/auth/health"
echo ""