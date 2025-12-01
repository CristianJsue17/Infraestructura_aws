#!/bin/bash

# ====================================
# ACTUALIZAR KUBECONFIG
# ====================================
echo "🔄 Actualizando kubeconfig..."
CLUSTER_NAME=$(aws eks list-clusters --region us-east-1 --query 'clusters[0]' --output text)
aws eks update-kubeconfig \
  --region us-east-1 \
  --name $CLUSTER_NAME \
  > /dev/null 2>&1
echo "✅ Kubeconfig actualizado"
echo ""

echo "=========================================="
echo "ARREGLAR SECURITY GROUPS - NODEPORTS"
echo "=========================================="
echo ""

# 1. Obtener todos los nodos del cluster
echo "1. IDENTIFICANDO NODOS Y SECURITY GROUPS:"
INSTANCE_IDS=$(kubectl get nodes -o jsonpath='{.items[*].spec.providerID}' | sed 's|aws:///[^/]*/||g')
echo "Instancias encontradas: $INSTANCE_IDS"
echo ""

# Tomar el primer nodo como referencia
FIRST_INSTANCE=$(echo $INSTANCE_IDS | awk '{print $1}')

# 2. Obtener todos los SG IDs
SG_IDS=$(aws ec2 describe-instances \
  --instance-ids $FIRST_INSTANCE \
  --region us-east-1 \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
  --output text)

echo "Security Groups encontrados: $SG_IDS"
echo ""

# 3. Agregar reglas a cada SG
for SG_ID in $SG_IDS; do
    SG_NAME=$(aws ec2 describe-security-groups \
      --group-ids $SG_ID \
      --region us-east-1 \
      --query 'SecurityGroups[0].GroupName' \
      --output text)
    
    echo "-------------------------------------------"
    echo "Procesando: $SG_NAME ($SG_ID)"
    echo ""
    
    # Agregar reglas para NodePorts
    echo "  Agregando: TCP 30080-30081 desde 10.0.0.0/16"
    aws ec2 authorize-security-group-ingress \
      --group-id $SG_ID \
      --protocol tcp \
      --port 30080-30081 \
      --cidr 10.0.0.0/16 \
      --region us-east-1 2>&1 | grep -v "already exists" || true
    
    echo "  Agregando: Todo el rango NodePort desde VPC"
    aws ec2 authorize-security-group-ingress \
      --group-id $SG_ID \
      --protocol tcp \
      --port 30000-32767 \
      --cidr 10.0.0.0/16 \
      --region us-east-1 2>&1 | grep -v "already exists" || true
    
    echo ""
done

echo "=========================================="
echo "ESPERANDO 90 SEGUNDOS PARA HEALTH CHECKS"
echo "=========================================="
sleep 90

# 4. Verificar Target Groups dinámicamente
echo ""
echo "VERIFICANDO ESTADO DE TARGET GROUPS:"
echo ""

TG_AUTH_ARN=$(aws elbv2 describe-target-groups \
  --region us-east-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `auth`)].TargetGroupArn' \
  --output text)

TG_PROD_ARN=$(aws elbv2 describe-target-groups \
  --region us-east-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `prod`)].TargetGroupArn' \
  --output text)

if [ ! -z "$TG_AUTH_ARN" ]; then
  echo "Target Group - Autenticación:"
  aws elbv2 describe-target-health \
    --target-group-arn $TG_AUTH_ARN \
    --region us-east-1 \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
    --output table
  echo ""
fi

if [ ! -z "$TG_PROD_ARN" ]; then
  echo "Target Group - Productos:"
  aws elbv2 describe-target-health \
    --target-group-arn $TG_PROD_ARN \
    --region us-east-1 \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
    --output table
fi

echo ""
echo "=========================================="
echo "✅ PROCESO COMPLETADO"
echo "=========================================="
echo ""
echo "Si los targets aún están unhealthy, espera 2-3 minutos más."