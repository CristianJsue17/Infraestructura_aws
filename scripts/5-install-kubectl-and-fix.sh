#!/bin/bash

echo "=========================================="
echo "INSTALACIÓN RÁPIDA DE KUBECTL + FIX"
echo "=========================================="
echo ""

# 1. Descargar kubectl
echo "1. Descargando kubectl para Windows..."
cd ~
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"

# 2. Crear directorio bin y mover kubectl
echo "2. Configurando kubectl..."
mkdir -p ~/bin
mv kubectl.exe ~/bin/
export PATH=$PATH:~/bin

# Agregar al .bashrc para que sea permanente
if ! grep -q 'export PATH=$PATH:~/bin' ~/.bashrc; then
    echo 'export PATH=$PATH:~/bin' >> ~/.bashrc
fi

# 3. Verificar instalación
echo ""
echo "3. Verificando instalación de kubectl..."
kubectl version --client

if [ $? -ne 0 ]; then
    echo "ERROR: kubectl no se instaló correctamente"
    exit 1
fi

echo ""
echo "✅ kubectl instalado correctamente!"
echo ""

# 4. Configurar acceso al cluster
echo "4. Configurando acceso al cluster EKS..."
aws eks update-kubeconfig --region us-east-1 --name microservicios-eks-cluster

if [ $? -ne 0 ]; then
    echo "ERROR: No se pudo configurar el acceso al cluster"
    exit 1
fi

echo ""
echo "✅ Acceso al cluster configurado!"
echo ""

# 5. Obtener ARN del usuario actual
echo "5. Obteniendo tu ARN de IAM..."
MY_ARN=$(aws sts get-caller-identity --query Arn --output text)
echo "Tu ARN: $MY_ARN"

# 6. Determinar tipo de ARN
if [[ $MY_ARN == *":user/"* ]]; then
    ARN_TYPE="userarn"
    USERNAME=$(echo $MY_ARN | sed 's/.*:user\///')
    echo "Tipo: Usuario de IAM - $USERNAME"
elif [[ $MY_ARN == *":role/"* ]]; then
    ARN_TYPE="rolearn"
    USERNAME=$(echo $MY_ARN | sed 's/.*:role\///')
    echo "Tipo: Rol de IAM - $USERNAME"
fi

echo ""
echo "6. Actualizando ConfigMap aws-auth..."

# 7. Crear y aplicar el ConfigMap completo
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::340234701922:role/microservicios-eks-node-group-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::340234701922:role/microservicios-bastion-role
      username: bastion-admin
      groups:
        - system:masters
  mapUsers: |
    - ${ARN_TYPE}: ${MY_ARN}
      username: ${USERNAME}
      groups:
        - system:masters
EOF

if [ $? -ne 0 ]; then
    echo "ERROR: No se pudo actualizar el ConfigMap"
    exit 1
fi

echo ""
echo "✅ ConfigMap aws-auth actualizado correctamente!"
echo ""

# 8. Verificar que ahora tienes acceso
echo "7. Verificando acceso a Kubernetes..."
echo ""
echo "NODOS:"
kubectl get nodes
echo ""
echo "PODS EN NAMESPACE MICROSERVICIOS:"
kubectl get pods -n microservicios -o wide
echo ""
echo "SERVICIOS:"
kubectl get svc -n microservicios
echo ""
echo "ENDPOINTS:"
kubectl get endpoints -n microservicios
echo ""

echo "=========================================="
echo "✅ INSTALACIÓN Y CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""
echo "Ahora puedes ejecutar comandos kubectl:"
echo "  kubectl get pods -n microservicios"
echo "  kubectl logs -n microservicios deployment/autenticacion"
echo "  kubectl exec -n microservicios deployment/autenticacion -- curl http://localhost:8000/health"
echo ""
