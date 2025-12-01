## 📚 EXPLICACIÓN COMPLETA DEL TROUBLESHOOTING

## 🔍 PARTE 1: LO QUE ENCONTRAMOS CON EL DIAGNÓSTICO
Script de Diagnóstico: 6-diagnostico-nodeports.sh
Este script probó cada capa de la arquitectura para encontrar dónde estaba el problema:
# ✅ LO QUE ESTABA BIEN:

1. **Pods corriendo perfectamente** ✅
    autenticacion-78fbc46fc6-2k6jh    1/1  Running
    productos-84bb66d59d-8dcsm        1/1  Running

- Los pods se levantaron correctamente
- Las aplicaciones estaban funcionando

2. **Servicio ClusterIP funcionando** ✅

    kubectl run test-clusterip -- curl http://autenticacion-service:8000/health
   # Resultado: {"estado":"saludable"}

- La comunicación dentro del cluster funcionaba
- kube-dns resolvía los nombres correctamente

3. **NodePort funcionando desde DENTRO del cluster** ✅

    curl http://10.0.24.53:30080/health
   # Resultado: HTTP/1.1 200 OK

   - kube-proxy configuró las reglas de iptables correctamente
   - Los NodePorts redirigían el tráfico a los pods

4. **kube-proxy corriendo bien** ✅

   I1130 01:15:48.332992  "Reloading service iptables data" 
   numServices=6 numEndpoints=13 numNATChains=25 numNATRules=56

   - El daemon kube-proxy estaba activo
   - Las reglas de NAT se crearon correctamente

## ❌ LO QUE ESTABA MAL:

1. **NLB Health Checks fallando** ❌

   i-0aca6d5948d57a102  unhealthy  Target.FailedHealthChecks
   i-0436fb2543b64801f  unhealthy  Target.FailedHealthChecks
   i-0c8041094815a69c3  unhealthy  Target.FailedHealthChecks

   - El NLB **NO podía** hacer health checks a los nodos
   - Todos los targets estaban "unhealthy"

2. **Security Group sin reglas para NodePorts** ❌

   Security Group de nodos: sg-01c12348d265154be
   Reglas de INGRESS: Solo puerto 5000 (???)

# - El SG del cluster EKS NO tenía reglas para puertos 30000-32767
# - Faltaban reglas para permitir tráfico desde el VPC CIDR



## 🛠️ PARTE 2: EL SCRIPT QUE SOLUCIONÓ EL PROBLEMA
# Script de Solución: 7-fix-security-groups.sh
# Este script hizo 3 cosas críticas:
1. Identificó el Security Group correcto
bashaws ec2 describe-instances --instance-ids i-0aca6d5948d57a102 \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].[GroupId,GroupName]'
  
# Resultado:
    sg-01c12348d265154be  eks-cluster-sg-microservicios-eks-cluster-1790935802
# Por qué esto es importante:
- EKS crea automáticamente su propio security group   <- OJO
- Este SG NO es el que definimos en Terraform
- Nuestro Terraform aplicaba reglas al SG equivocado

2. Agregó las reglas de ingress necesarias
# Regla 1: NodePort específico para autenticación
aws ec2 authorize-security-group-ingress \
  --group-id sg-01c12348d265154be \
  --protocol tcp \
  --port 30080 \
  --cidr 10.0.0.0/16

# Regla 2: NodePort específico para productos  
aws ec2 authorize-security-group-ingress \
  --group-id sg-01c12348d265154be \
  --protocol tcp \
  --port 30081 \
  --cidr 10.0.0.0/16

# Regla 3: Todos los NodePorts (rango completo)
aws ec2 authorize-security-group-ingress \
  --group-id sg-01c12348d265154be \
  --protocol tcp \
  --port 30000-32767 \
  --cidr 10.0.0.0/16


## 🎓 **PARTE 3: CONCEPTOS - ¿POR QUÉ FALTABA ESO?**

# **Arquitectura de Kubernetes con NodePort**
┌────────────────────────────────────────────────────────────┐
│  VPC (10.0.0.0/16)                                         │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Network Load Balancer (NLB)                         │ │
│  │  - Listener :8000 → Target Group (puerto 30080)      │ │
│  │  - Hace health checks: HTTP GET /health en 30080     │ │
│  └──────────────────┬───────────────────────────────────┘ │
│                     │                                      │
│                     ▼                                      │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  EC2 Nodes (Workers de EKS)                          │ │
│  │                                                        │ │
│  │  ┌──────────────────────────────────────────────┐   │ │
│  │  │ Security Group: sg-01c12348d265154be        │   │ │
│  │  │                                               │   │ │
│  │  │ INGRESS Rules (lo que FALTABA):              │   │ │
│  │  │ ✅ TCP 30080 from 10.0.0.0/16                │   │ │
│  │  │ ✅ TCP 30081 from 10.0.0.0/16                │   │ │
│  │  │ ✅ TCP 30000-32767 from 10.0.0.0/16          │   │ │
│  │  └──────────────────────────────────────────────┘   │ │
│  │                     │                                 │ │
│  │                     ▼                                 │ │
│  │  ┌──────────────────────────────────────────────┐   │ │
│  │  │ kube-proxy (iptables)                        │   │ │
│  │  │ - Escucha en 0.0.0.0:30080                   │   │ │
│  │  │ - Redirige a pods en puerto 8000             │   │ │
│  │  └──────────────┬───────────────────────────────┘   │ │
│  │                 │                                     │ │
│  │                 ▼                                     │ │
│  │  ┌──────────────────────────────────────────────┐   │ │
│  │  │ Pods (autenticacion:8000)                    │   │ │
│  │  │ - 10.0.46.76:8000                            │   │ │
│  │  │ - 10.0.7.181:8000                            │   │ │
│  │  │ - 10.0.30.167:8000                           │   │ │
│  │  └──────────────────────────────────────────────┘   │ │
│  └──────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

# **¿Qué es un NodePort?**
Un NodePort expone un servicio en todos los nodos del cluster en un puerto específico (30000-32767):
    Service:
        type: NodePort
        port: 8000          # Puerto interno del servicio
        targetPort: 8000    # Puerto del pod
        nodePort: 30080     # Puerto expuesto en TODOS los nodos

**Esto significa que:**
- Puedes acceder al servicio en `NODE_IP:30080` desde **cualquier nodo**
- kube-proxy crea reglas de iptables que escuchan en `0.0.0.0:30080`
- El tráfico se redirige automáticamente a los pods

### **¿Por qué el NLB necesita acceso a los NodePorts?**

El NLB hace **health checks** directamente a los nodos:

NLB Health Check:
  Protocol: HTTP
  Path: /health
  Port: 30080
  Target: 10.0.24.53 (IP del nodo)
  
Flujo:
1. NLB envía: HTTP GET http://10.0.24.53:30080/health
2. Security Group del nodo debe PERMITIR puerto 30080 desde VPC
3. kube-proxy intercepta y redirige a pod
4. Pod responde con {"estado":"saludable"}
5. NLB marca target como "healthy" ✅


**SIN las reglas de security group:**

1. NLB envía: HTTP GET http://10.0.24.53:30080/health
2. Security Group BLOQUEA el tráfico ❌
3. NLB no recibe respuesta
4. NLB marca target como "unhealthy" ❌




##  ¿Qué hizo el script que solucionó el problema?
El script 7-fix-security-groups.sh hizo 3 cosas:

- Identificó el SG correcto: sg-01c12348d265154be
- Agregó 3 reglas de ingress:
    - TCP 30080 desde 10.0.0.0/16 (auth)
    - TCP 30081 desde 10.0.0.0/16 (productos)
    - TCP 30000-32767 desde 10.0.0.0/16 (todos los NodePorts)

Verificó que funcionó: Target groups pasaron a "healthy" ✅


## ¿Por qué faltaba eso? (Concepto de infraestructura)
**NodePort = Puerto expuesto en TODOS los nodos del cluster (30000-32767)**
Flujo completo:
    Internet → API GW → VPC Link → NLB → [SG debe PERMITIR] → Nodos:30080 → kube-proxy → Pods:8000
# Sin la regla de SG:
 NLB intenta: GET http://10.0.24.53:30080/health
    - Security Group: ❌ BLOQUEA (no hay regla para puerto 30080)
    - NLB: "unhealthy" porque no recibe respuesta
 Con la regla de SG:
    - NLB intenta: GET http://10.0.24.53:30080/health
    - Security Group: ✅ PERMITE (regla TCP 30080 desde 10.0.0.0/16)
    - kube-proxy: ✅ Redirige al pod
    - NLB: "healthy" ✅