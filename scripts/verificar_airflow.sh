#!/bin/bash
# Script para verificar el estado de Airflow
# Ejecutar desde tu máquina local

SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"
EC2_IP="18.118.31.28"

echo "=========================================="
echo "🔍 VERIFICANDO ESTADO DE AIRFLOW"
echo "=========================================="
echo ""

# Verificar que existe la clave SSH
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ Error: No se encuentra la clave SSH en: $SSH_KEY"
    exit 1
fi

# Verificar conectividad
echo "📡 Verificando conectividad a EC2..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$EC2_HOST" "echo 'OK'" > /dev/null 2>&1; then
    echo "   ✅ Conexión a EC2 exitosa"
else
    echo "   ❌ No se puede conectar a EC2"
    exit 1
fi

echo ""
echo "📋 Verificando servicios en EC2..."
echo ""

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
export AIRFLOW_HOME=~/airflow

echo "1. Verificando procesos de Airflow..."
echo ""
WEBSERVER=$(ps aux | grep -E "[g]unicorn.*airflow" | head -1)
SCHEDULER=$(ps aux | grep -E "[a]irflow scheduler" | grep -v grep | head -1)

if [ ! -z "$WEBSERVER" ]; then
    echo "   ✅ Webserver está corriendo:"
    echo "      $WEBSERVER"
else
    echo "   ❌ Webserver NO está corriendo"
fi

if [ ! -z "$SCHEDULER" ]; then
    echo "   ✅ Scheduler está corriendo:"
    echo "      $SCHEDULER"
else
    echo "   ❌ Scheduler NO está corriendo"
fi

echo ""
echo "2. Verificando puerto 8080..."
if ss -tlnp 2>/dev/null | grep -q ":8080"; then
    echo "   ✅ Puerto 8080 está escuchando:"
    ss -tlnp 2>/dev/null | grep 8080
elif netstat -tlnp 2>/dev/null | grep -q ":8080"; then
    echo "   ✅ Puerto 8080 está escuchando:"
    netstat -tlnp 2>/dev/null | grep 8080
else
    echo "   ❌ Puerto 8080 NO está escuchando"
fi

echo ""
echo "3. Verificando acceso HTTP..."
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/login 2>/dev/null || echo "000")
if [ "$HTTP_RESPONSE" = "200" ]; then
    echo "   ✅ Webserver responde correctamente (HTTP $HTTP_RESPONSE)"
elif [ "$HTTP_RESPONSE" = "000" ]; then
    echo "   ❌ Webserver no responde (sin conexión)"
else
    echo "   ⚠️  Webserver responde con código: $HTTP_RESPONSE"
fi

echo ""
echo "4. Verificando configuración de Airflow..."
if [ -f $AIRFLOW_HOME/airflow.cfg ]; then
    echo "   ✅ airflow.cfg existe"
    
    # Verificar configuración de base de datos
    DB_CONN=$(grep "^sql_alchemy_conn" $AIRFLOW_HOME/airflow.cfg | cut -d'=' -f2 | tr -d ' ')
    if [[ "$DB_CONN" == *"postgresql"* ]]; then
        echo "   ✅ Base de datos configurada (PostgreSQL)"
    else
        echo "   ⚠️  Base de datos: $DB_CONN"
    fi
else
    echo "   ❌ airflow.cfg no existe"
fi

echo ""
echo "5. Verificando DAGs..."
if [ -d $AIRFLOW_HOME/dags ]; then
    DAG_COUNT=$(find $AIRFLOW_HOME/dags -name "*.py" -type f | wc -l)
    echo "   ✅ Directorio de DAGs existe"
    echo "   📁 DAGs encontrados: $DAG_COUNT"
    if [ "$DAG_COUNT" -gt 0 ]; then
        echo "   Archivos:"
        find $AIRFLOW_HOME/dags -name "*.py" -type f | head -5 | sed 's/^/      - /'
    fi
else
    echo "   ❌ Directorio de DAGs no existe"
fi

echo ""
echo "6. Verificando logs recientes..."
echo ""
echo "   Webserver (últimas 5 líneas):"
if [ -f /tmp/airflow_webserver.log ]; then
    tail -5 /tmp/airflow_webserver.log | sed 's/^/      /'
else
    echo "      (log no encontrado)"
fi

echo ""
echo "   Scheduler (últimas 5 líneas):"
if [ -f /tmp/airflow_scheduler.log ]; then
    tail -5 /tmp/airflow_scheduler.log | sed 's/^/      /'
else
    echo "      (log no encontrado)"
fi

echo ""
echo "=========================================="
echo "RESUMEN"
echo "=========================================="
if [ ! -z "$WEBSERVER" ] && [ ! -z "$SCHEDULER" ]; then
    echo "✅ Airflow debería estar funcionando correctamente"
    echo ""
    echo "Accede a: http://18.118.31.28:8080"
    echo "Usuario: admin"
    echo "Contraseña: admin"
else
    echo "❌ Hay problemas con los servicios de Airflow"
    echo ""
    echo "Ejecuta el script de reparación:"
    echo "  ./scripts/fix_airflow_complete.sh"
fi
ENDSSH

echo ""


