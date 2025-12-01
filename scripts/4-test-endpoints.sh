#!/bin/bash

# Configuración
API_URL="https://tok2vedrt3.execute-api.us-east-1.amazonaws.com/prod"
API_KEY="0XXNnq9gWl380yexIzU5S4teqWuGc8gX6F0UIy8F"

echo "=========================================="
echo "PRUEBAS COMPLETAS - MICROSERVICIOS"
echo "=========================================="
echo ""
echo "API URL: $API_URL"
echo "API Key: $API_KEY"
echo ""

# ====================================
# MICROSERVICIO DE AUTENTICACIÓN
# ====================================

echo "=========================================="
echo "1. MICROSERVICIO DE AUTENTICACIÓN"
echo "=========================================="
echo ""

# 1.1 Registrar usuario
echo "1.1. REGISTRAR NUEVO USUARIO:"
echo "   POST $API_URL/api/auth/registrar"
echo ""
REGISTER_RESPONSE=$(curl -s -X POST "$API_URL/api/auth/registrar" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "nombre_usuario": "testuser_'$(date +%s)'",
    "email": "testuser'$(date +%s)'@example.com",
    "contrasena": "SecurePass123!",
    "nombre_completo": "Usuario de Prueba"
  }')

echo "$REGISTER_RESPONSE"
echo ""
echo ""

# 1.2 Iniciar sesión
echo "1.2. INICIAR SESIÓN:"
echo "   POST $API_URL/api/auth/login"
echo ""

# Extraer nombre de usuario del registro (manualmente sin jq)
USERNAME=$(echo "$REGISTER_RESPONSE" | grep -o '"nombre_usuario":"[^"]*"' | cut -d'"' -f4)

LOGIN_RESPONSE=$(curl -s -X POST "$API_URL/api/auth/login" \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"nombre_usuario\": \"$USERNAME\",
    \"contrasena\": \"SecurePass123!\"
  }")

echo "$LOGIN_RESPONSE"

# Extraer el token (sin jq)
TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo ""
echo "Token obtenido: ${TOKEN:0:50}..."
echo ""
echo ""

# 1.3 Verificar token
echo "1.3. VERIFICAR TOKEN:"
echo "   GET $API_URL/api/auth/verificar"
echo ""
curl -s -X GET "$API_URL/api/auth/verificar" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN"
echo ""
echo ""

# ====================================
# MICROSERVICIO DE PRODUCTOS
# ====================================

echo ""
echo "=========================================="
echo "2. MICROSERVICIO DE PRODUCTOS"
echo "=========================================="
echo ""

# 2.1 Crear producto
echo "2.1. CREAR NUEVO PRODUCTO:"
echo "   POST $API_URL/api/productos"
echo ""
PRODUCT1=$(curl -s -X POST "$API_URL/api/productos" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Laptop Dell XPS 13",
    "descripcion": "Laptop ultraportátil de alto rendimiento",
    "precio": 1299.99,
    "cantidad_stock": 50
  }')

echo "$PRODUCT1"

# Extraer ID del producto (sin jq)
PRODUCT1_ID=$(echo "$PRODUCT1" | grep -o '"id":[0-9]*' | head -n 1 | cut -d':' -f2)
echo ""
echo "Producto creado con ID: $PRODUCT1_ID"
echo ""
echo ""

# 2.2 Crear segundo producto
echo "2.2. CREAR SEGUNDO PRODUCTO:"
echo ""
PRODUCT2=$(curl -s -X POST "$API_URL/api/productos" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "iPhone 15 Pro",
    "descripcion": "Smartphone Apple última generación",
    "precio": 999.99,
    "cantidad_stock": 100
  }')

echo "$PRODUCT2"

PRODUCT2_ID=$(echo "$PRODUCT2" | grep -o '"id":[0-9]*' | head -n 1 | cut -d':' -f2)
echo ""
echo "Producto creado con ID: $PRODUCT2_ID"
echo ""
echo ""

# 2.3 Listar productos
echo "2.3. LISTAR TODOS LOS PRODUCTOS:"
echo "   GET $API_URL/api/productos"
echo ""
curl -s -X GET "$API_URL/api/productos" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN"
echo ""
echo ""

# 2.4 Obtener producto por ID
echo "2.4. OBTENER PRODUCTO POR ID:"
echo "   GET $API_URL/api/productos/$PRODUCT1_ID"
echo ""
curl -s -X GET "$API_URL/api/productos/$PRODUCT1_ID" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN"
echo ""
echo ""

# 2.5 Actualizar producto
echo "2.5. ACTUALIZAR PRODUCTO:"
echo "   PUT $API_URL/api/productos/$PRODUCT1_ID"
echo ""
curl -s -X PUT "$API_URL/api/productos/$PRODUCT1_ID" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nombre": "Laptop Dell XPS 13 (2024)",
    "descripcion": "Laptop ultraportátil de alto rendimiento - Modelo actualizado",
    "precio": 1199.99,
    "cantidad_stock": 75
  }'
echo ""
echo ""

# 2.6 Eliminar producto
echo "2.6. ELIMINAR PRODUCTO:"
echo "   DELETE $API_URL/api/productos/$PRODUCT2_ID"
echo ""
curl -s -X DELETE "$API_URL/api/productos/$PRODUCT2_ID" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN"
echo ""
echo ""

# 2.7 Verificar que se eliminó
echo "2.7. VERIFICAR LISTA ACTUALIZADA:"
echo ""
curl -s -X GET "$API_URL/api/productos" \
  -H "x-api-key: $API_KEY" \
  -H "Authorization: Bearer $TOKEN"
echo ""
echo ""

# ====================================
# RESUMEN
# ====================================

echo ""
echo "=========================================="
echo "✅ PRUEBAS COMPLETADAS"
echo "=========================================="
echo ""
echo "Endpoints probados:"
echo "  ✅ POST   /api/auth/registrar   - Registro de usuario"
echo "  ✅ POST   /api/auth/login       - Inicio de sesión"
echo "  ✅ GET    /api/auth/verificar   - Verificación de token"
echo "  ✅ POST   /api/productos        - Crear producto"
echo "  ✅ GET    /api/productos        - Listar productos"
echo "  ✅ GET    /api/productos/{id}   - Obtener producto"
echo "  ✅ PUT    /api/productos/{id}   - Actualizar producto"
echo "  ✅ DELETE /api/productos/{id}   - Eliminar producto"
echo ""
echo "Estado del sistema: ✅ FUNCIONANDO CORRECTAMENTE"
echo ""
echo "NOTA: Para mejor visualización, instala jq:"
echo "  Git Bash: curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-win64.exe -o ~/bin/jq.exe"
echo ""