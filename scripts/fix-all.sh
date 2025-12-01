#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           SCRIPT MAESTRO AUTO-CORRECTIVO v1.0                ║"
echo "║              Verifica y corrige automáticamente              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Modo dry-run
DRY_RUN=${1:-"false"}
if [ "$DRY_RUN" == "--dry-run" ]; then
    echo "🔍 Modo DRY-RUN activado (solo verifica, no corrige)"
    echo ""
fi

FIXES_APPLIED=0

# ============================================================================
# FUNCIÓN: Verificar si un comando necesita ejecutarse
# ============================================================================
execute_fix() {
    local description=$1
    local command=$2
    
    if [ "$DRY_RUN" == "--dry-run" ]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $description"
        echo "  Comando: $command"
    else
        echo -e "${BLUE}[FIXING]${NC} $description"
        if eval "$command" >/dev/null 2>&1; then
            echo -e "${GREEN}  ✅ Corregido${NC}"
            ((FIXES_APPLIED++))
        else
            echo -e "${RED}  ❌ Error al corregir (puede que ya esté bien)${NC}"
        fi
    fi
}

# ============================================================================
echo "═══════════════════════════════════════════════════════════════"
echo "PASO 1: DETECCIÓN AUTOMÁTICA DE RECURSOS"
echo "═══════════════════════════════════════════════════════════════"

# Detectar cluster
CLUSTER_NAME=$(aws eks list-clusters --query 'clusters[0]' --output text 2>/dev/null)
if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${RED}❌ No se encontró cluster EKS${NC}"
    exit 1
fi
echo -e "${GREEN}✅${NC} Cluster: $CLUSTER_NAME"

# Detectar región
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
fi
echo -e "${GREEN}✅${NC} Región: $AWS_REGION"

# Verificar kubeconfig
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null)
EXPECTED_CONTEXT="arn:aws:eks:${AWS_REGION}:*:cluster/${CLUSTER_NAME}"

if [[ ! "$CURRENT_CONTEXT" =~ "$CLUSTER_NAME" ]]; then
    echo -e "${YELLOW}⚠️${NC} Kubeconfig desactualizado, actualizando..."
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION >/dev/null 2>&1
    echo -e "${GREEN}✅${NC} Kubeconfig actualizado"
else
    echo -e "${GREEN}✅${NC} Kubeconfig correcto"
fi

# Variables dinámicas
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.resourcesVpcConfig.vpcId' --output text)
EKS_CLUSTER_SG=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].CidrBlock' --output text)

echo -e "${GREEN}✅${NC} VPC: $VPC_ID ($VPC_CIDR)"
echo -e "${GREEN}✅${NC} EKS Cluster SG: $EKS_CLUSTER_SG"

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "PASO 2: VERIFICAR Y CORREGIR SECURITY GROUPS DE NODOS"
echo "═══════════════════════════════════════════════════════════════"

# Obtener Security Groups de nodos
NODE_IDS=($(kubectl get nodes -o jsonpath='{.items[*].spec.providerID}' | sed 's|.*\/||g'))
if [ ${#NODE_IDS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No se encontraron nodos${NC}"
    exit 1
fi

NODE_SG=$(aws ec2 describe-instances --instance-ids ${NODE_IDS[0]} --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' --output text)

for SG in $NODE_SG; do
    SG_NAME=$(aws ec2 describe-security-groups --group-ids $SG --query 'SecurityGroups[0].GroupName' --output text)
    echo "📋 Verificando SG: $SG ($SG_NAME)"
    
    # Verificar reglas para NodePorts 30080-30081
    NODEPORT_RULE_EXISTS=$(aws ec2 describe-security-groups --group-ids $SG \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`30080\` && ToPort==\`30081\`] | length(@)" \
        --output text)
    
    if [ "$NODEPORT_RULE_EXISTS" == "0" ]; then
        echo -e "${YELLOW}  ⚠️  Falta regla NodePorts 30080-30081${NC}"
        execute_fix "Agregar regla NodePorts 30080-30081" \
            "aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 30080-30081 --cidr $VPC_CIDR --region $AWS_REGION"
    else
        echo -e "${GREEN}  ✅ Regla NodePorts OK${NC}"
    fi
    
    # Verificar regla para rango completo 30000-32767
    FULL_RANGE_EXISTS=$(aws ec2 describe-security-groups --group-ids $SG \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`30000\` && ToPort==\`32767\`] | length(@)" \
        --output text)
    
    if [ "$FULL_RANGE_EXISTS" == "0" ]; then
        echo -e "${YELLOW}  ⚠️  Falta regla rango completo NodePorts${NC}"
        execute_fix "Agregar regla rango completo NodePorts (30000-32767)" \
            "aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 30000-32767 --cidr $VPC_CIDR --region $AWS_REGION"
    else
        echo -e "${GREEN}  ✅ Regla rango completo OK${NC}"
    fi
done

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "PASO 3: VERIFICAR Y CORREGIR SECURITY GROUPS DE RDS"
echo "═══════════════════════════════════════════════════════════════"

# RDS Productos
RDS_PROD_SG=$(aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier, `productos`)].VpcSecurityGroups[0].VpcSecurityGroupId' \
    --output text 2>/dev/null)

if [ -n "$RDS_PROD_SG" ]; then
    echo "📊 Verificando RDS Productos SG: $RDS_PROD_SG"
    
    # Verificar si ya tiene regla desde EKS Cluster SG
    RDS_PROD_HAS_EKS_RULE=$(aws ec2 describe-security-groups --group-ids $RDS_PROD_SG \
        --query "SecurityGroups[0].IpPermissions[?ToPort==\`5432\`].UserIdGroupPairs[?GroupId==\`$EKS_CLUSTER_SG\`] | length(@)" \
        --output text)
    
    if [ "$RDS_PROD_HAS_EKS_RULE" == "0" ]; then
        echo -e "${YELLOW}  ⚠️  Falta regla desde EKS Cluster SG${NC}"
        execute_fix "Permitir acceso desde EKS a RDS Productos" \
            "aws ec2 authorize-security-group-ingress --group-id $RDS_PROD_SG --protocol tcp --port 5432 --source-group $EKS_CLUSTER_SG --region $AWS_REGION"
    else
        echo -e "${GREEN}  ✅ Regla desde EKS OK${NC}"
    fi
    
    # Verificar si tiene regla desde VPC CIDR
    RDS_PROD_HAS_VPC_RULE=$(aws ec2 describe-security-groups --group-ids $RDS_PROD_SG \
        --query "SecurityGroups[0].IpPermissions[?ToPort==\`5432\`].IpRanges[?CidrIp==\`$VPC_CIDR\`] | length(@)" \
        --output text)
    
    if [ "$RDS_PROD_HAS_VPC_RULE" == "0" ]; then
        echo -e "${YELLOW}  ⚠️  Falta regla desde VPC CIDR${NC}"
        execute_fix "Permitir acceso desde VPC a RDS Productos" \
            "aws ec2 authorize-security-group-ingress --group-id $RDS_PROD_SG --protocol tcp --port 5432 --cidr $VPC_CIDR --region $AWS_REGION"
    else
        echo -e "${GREEN}  ✅ Regla desde VPC OK${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No se encontró RDS Productos${NC}"
fi

# RDS Autenticación
RDS_AUTH_SG=$(aws rds describe-db-instances \
    --query 'DBInstances[?contains(DBInstanceIdentifier, `autenticacion`)].VpcSecurityGroups[0].VpcSecurityGroupId' \
    --output text 2>/dev/null)

if [ -n "$RDS_AUTH_SG" ]; then
    echo ""
    echo "📊 Verificando RDS Autenticación SG: $RDS_AUTH_SG"
    
    # Verificar si ya tiene regla desde EKS Cluster SG
    RDS_AUTH_HAS_EKS_RULE=$(aws ec2 describe-security-groups --group-ids $RDS_AUTH_SG \
        --query "SecurityGroups[0].IpPermissions[?ToPort==\`5432\`].UserIdGroupPairs[?GroupId==\`$EKS_CLUSTER_SG\`] | length(@)" \
        --output text)
    
    if [ "$RDS_AUTH_HAS_EKS_RULE" == "0" ]; then
        echo -e "${YELLOW}  ⚠️  Falta regla desde EKS Cluster SG${NC}"
        execute_fix "Permitir acceso desde EKS a RDS Autenticación" \
            "aws ec2 authorize-security-group-ingress --group-id $RDS_AUTH_SG --protocol tcp --port 5432 --source-group $EKS_CLUSTER_SG --region $AWS_REGION"
    else
        echo -e "${GREEN}  ✅ Regla desde EKS OK${NC}"
    fi
    
    # Verificar si tiene regla desde VPC CIDR
    RDS_AUTH_HAS_VPC_RULE=$(aws ec2 describe-security-groups --group-ids $RDS_AUTH_SG \
        --query "SecurityGroups[0].IpPermissions[?ToPort==\`5432\`].IpRanges[?CidrIp==\`$VPC_CIDR\`] | length(@)" \
        --output text)
    
    if [ "$RDS_AUTH_HAS_VPC_RULE" == "0" ]; then
        echo -e "${YELLOW}  ⚠️  Falta regla desde VPC CIDR${NC}"
        execute_fix "Permitir acceso desde VPC a RDS Autenticación" \
            "aws ec2 authorize-security-group-ingress --group-id $RDS_AUTH_SG --protocol tcp --port 5432 --cidr $VPC_CIDR --region $AWS_REGION"
    else
        echo -e "${GREEN}  ✅ Regla desde VPC OK${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No se encontró RDS Autenticación${NC}"
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "PASO 4: VERIFICAR ESTADO DE PODS"
echo "═══════════════════════════════════════════════════════════════"

# Si se aplicaron fixes de RDS, reiniciar pods
if [ "$FIXES_APPLIED" -gt 0 ] && [ "$DRY_RUN" != "--dry-run" ]; then
    echo -e "${BLUE}[ACCIÓN]${NC} Se aplicaron fixes, reiniciando pods..."
    
    kubectl rollout restart deployment autenticacion -n microservicios >/dev/null 2>&1
    kubectl rollout restart deployment productos -n microservicios >/dev/null 2>&1
    
    echo "⏳ Esperando 30 segundos para que los pods se estabilicen..."
    sleep 30
fi

# Verificar estado de pods
AUTH_RUNNING=$(kubectl get pods -n microservicios -l app=autenticacion --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
PROD_RUNNING=$(kubectl get pods -n microservicios -l app=productos --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

echo "📦 Pods autenticación Running: $AUTH_RUNNING"
echo "📦 Pods productos Running: $PROD_RUNNING"

if [ "$AUTH_RUNNING" -ge 1 ] && [ "$PROD_RUNNING" -ge 1 ]; then
    echo -e "${GREEN}✅ Pods funcionando correctamente${NC}"
else
    echo -e "${YELLOW}⚠️  Algunos pods no están Running${NC}"
    
    # Mostrar pods con problemas
    PROBLEM_PODS=$(kubectl get pods -n microservicios --field-selector=status.phase!=Running --no-headers 2>/dev/null)
    if [ -n "$PROBLEM_PODS" ]; then
        echo "Pods con problemas:"
        echo "$PROBLEM_PODS"
    fi
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "PASO 5: VERIFICAR TARGET GROUPS DEL NLB"
echo "═══════════════════════════════════════════════════════════════"

AUTH_TG_ARN=$(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?contains(TargetGroupName, `auth`)].TargetGroupArn' \
    --output text 2>/dev/null)

if [ -n "$AUTH_TG_ARN" ]; then
    HEALTHY_AUTH=$(aws elbv2 describe-target-health --target-group-arn $AUTH_TG_ARN \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
        --output text)
    TOTAL_AUTH=$(aws elbv2 describe-target-health --target-group-arn $AUTH_TG_ARN \
        --query 'length(TargetHealthDescriptions)' \
        --output text)
    
    echo "🎯 Target Group Autenticación: $HEALTHY_AUTH/$TOTAL_AUTH healthy"
    
    if [ "$HEALTHY_AUTH" == "$TOTAL_AUTH" ]; then
        echo -e "${GREEN}  ✅ Todos los targets healthy${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Algunos targets unhealthy${NC}"
    fi
fi

PROD_TG_ARN=$(aws elbv2 describe-target-groups \
    --query 'TargetGroups[?contains(TargetGroupName, `prod`)].TargetGroupArn' \
    --output text 2>/dev/null)

if [ -n "$PROD_TG_ARN" ]; then
    HEALTHY_PROD=$(aws elbv2 describe-target-health --target-group-arn $PROD_TG_ARN \
        --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
        --output text)
    TOTAL_PROD=$(aws elbv2 describe-target-health --target-group-arn $PROD_TG_ARN \
        --query 'length(TargetHealthDescriptions)' \
        --output text)
    
    echo "🎯 Target Group Productos: $HEALTHY_PROD/$TOTAL_PROD healthy"
    
    if [ "$HEALTHY_PROD" == "$TOTAL_PROD" ]; then
        echo -e "${GREEN}  ✅ Todos los targets healthy${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Algunos targets unhealthy (pueden tardar 2-3 min)${NC}"
    fi
fi

# ============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "PASO 6: VERIFICAR API GATEWAY"
echo "═══════════════════════════════════════════════════════════════"

API_ID=$(aws apigateway get-rest-apis --query 'items[?name==`microservicios-api`].id' --output text 2>/dev/null)
VPC_LINK_ID=$(aws apigateway get-vpc-links --query 'items[0].id' --output text 2>/dev/null)
VPC_LINK_STATUS=$(aws apigateway get-vpc-links --query 'items[0].status' --output text 2>/dev/null)

if [ -n "$API_ID" ]; then
    echo -e "${GREEN}✅${NC} API Gateway: $API_ID"
fi

if [ -n "$VPC_LINK_ID" ]; then
    echo -e "${GREEN}✅${NC} VPC Link: $VPC_LINK_ID"
    
    if [ "$VPC_LINK_STATUS" == "AVAILABLE" ]; then
        echo -e "${GREEN}✅${NC} VPC Link Status: AVAILABLE"
    else
        echo -e "${YELLOW}⚠️${NC} VPC Link Status: $VPC_LINK_STATUS"
    fi
fi

# ============================================================================
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                      RESUMEN FINAL                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [ "$DRY_RUN" == "--dry-run" ]; then
    echo -e "${YELLOW}Modo DRY-RUN: No se aplicaron cambios${NC}"
    echo "Ejecuta sin --dry-run para aplicar correcciones"
else
    if [ "$FIXES_APPLIED" -eq 0 ]; then
        echo -e "${GREEN}✅ Todo está correcto, no se requirieron correcciones${NC}"
    else
        echo -e "${GREEN}✅ Se aplicaron $FIXES_APPLIED correcciones${NC}"
        echo ""
        echo "⏳ IMPORTANTE: Los Target Groups pueden tardar 2-3 minutos"
        echo "   en reportar 'healthy' después de los cambios."
        echo ""
        echo "🔄 Para verificar el estado final, ejecuta:"
        echo "   ./9-diagnostico-completo.sh"
    fi
fi

echo ""
echo "🚀 URL de API Gateway:"
if [ -n "$API_ID" ]; then
    echo "   https://$API_ID.execute-api.$AWS_REGION.amazonaws.com/prod"
fi

echo ""
echo "✨ Script completado exitosamente"