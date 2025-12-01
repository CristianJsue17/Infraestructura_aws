#!/bin/bash

# ====================================
# CONFIGURACIÓN DINÁMICA
# ====================================
echo "🔄 Actualizando kubeconfig..."
CLUSTER_NAME=$(aws eks list-clusters --region us-east-1 --query 'clusters[0]' --output text)
aws eks update-kubeconfig \
  --region us-east-1 \
  --name $CLUSTER_NAME \
  --alias microservicios \
  > /dev/null 2>&1
echo "✅ Kubeconfig actualizado para cluster: $CLUSTER_NAME"
echo ""

echo "=========================================="
echo "DIAGNÓSTICO COMPLETO - NODEPORTS & NLB"
echo "=========================================="
echo ""

# Obtener ARN del Target Group dinámicamente
TG_AUTH_ARN=$(aws elbv2 describe-target-groups \
  --region us-east-1 \
  --query 'TargetGroups[?contains(TargetGroupName, `auth`)].TargetGroupArn' \
  --output text | head -n 1)

echo "Target Group ARN detectado: $TG_AUTH_ARN"
echo ""

# Obtener primer nodo dinámicamente
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Nodo detectado: $NODE_NAME ($NODE_IP)"
echo ""

# Obtener ID de instancia del primer nodo
INSTANCE_ID=$(aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=private-ip-address,Values=$NODE_IP" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)
echo "Instance ID: $INSTANCE_ID"
echo ""

# 1. Probar health check directo
echo "1. PROBANDO HEALTH CHECK DIRECTO EN POD:"
kubectl exec -n microservicios deployment/autenticacion -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health').read().decode())" 2>/dev/null || echo "❌ No se pudo acceder"
echo ""

# 2. Probar servicio ClusterIP
echo "2. PROBANDO SERVICIO CLUSTERIP:"
kubectl run test-clusterip --image=curlimages/curl --rm -it --restart=Never -- curl -s http://autenticacion-service.microservicios:8000/health 2>&1 | tail -n 1
echo ""

# 3. Probar NodePort
echo "3. PROBANDO NODEPORT DESDE DENTRO DEL CLUSTER:"
echo "   Nodo: $NODE_IP:30080"
kubectl run test-nodeport --image=curlimages/curl --rm -it --restart=Never -- curl -s http://$NODE_IP:30080/health 2>&1 | tail -n 1
echo ""

# 4. Estado Target Group
echo "4. ESTADO DEL TARGET GROUP:"
if [ ! -z "$TG_AUTH_ARN" ]; then
  aws elbv2 describe-target-health \
    --target-group-arn $TG_AUTH_ARN \
    --region us-east-1 \
    --query 'TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason]' \
    --output table
else
  echo "❌ Target Group no encontrado"
fi
echo ""

# 5. Security Groups del nodo
echo "5. SECURITY GROUPS DEL NODO:"
if [ ! -z "$INSTANCE_ID" ]; then
  NODE_SG=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region us-east-1 \
    --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
    --output text)
  echo "   Security Groups: $NODE_SG"
  
  for SG in $NODE_SG; do
    echo ""
    echo "   Reglas de $SG:"
    aws ec2 describe-security-groups \
      --group-ids $SG \
      --region us-east-1 \
      --query 'SecurityGroups[0].IpPermissions[?FromPort==`30080` || ToPort==`30081`].[FromPort,ToPort,IpProtocol,IpRanges[*].CidrIp,UserIdGroupPairs[*].GroupId]' \
      --output table 2>/dev/null || echo "   Sin reglas para NodePorts"
  done
else
  echo "❌ Instancia no encontrada"
fi
echo ""

# 6. Logs kube-proxy
echo "6. LOGS DE KUBE-PROXY (últimas 10 líneas):"
kubectl logs -n kube-system -l k8s-app=kube-proxy --tail=10 2>&1 | tail -n 10
echo ""

echo "=========================================="
echo "DIAGNÓSTICO COMPLETADO"
echo "=========================================="