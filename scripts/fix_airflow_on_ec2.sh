#!/bin/bash
# Script para solucionar problemas de Airflow
# EJECUTAR ESTE SCRIPT DIRECTAMENTE EN EC2 (después de conectarte por SSH)

set -e

echo "=========================================="
echo "🔧 SOLUCIONANDO PROBLEMAS DE AIRFLOW"
echo "=========================================="
echo ""

export AIRFLOW_HOME=~/airflow

# Verificar si existe el entorno virtual
if [ ! -d ~/airflow-env ]; then
    echo "❌ No se encuentra el entorno virtual de Airflow"
    echo "   Por favor, ejecuta primero el script de instalación"
    exit 1
fi

# Activar entorno virtual
source ~/airflow-env/bin/activate

# Verificar instalación de Airflow
if ! command -v airflow &> /dev/null; then
    echo "❌ Airflow no está instalado"
    exit 1
fi

echo "✅ Entorno de Airflow verificado"
echo ""

echo "📋 Verificando procesos actuales..."
WEBSERVER_RUNNING=$(ps aux | grep -E "[g]unicorn.*airflow" | wc -l)
SCHEDULER_RUNNING=$(ps aux | grep -E "[a]irflow scheduler" | grep -v grep | wc -l)

if [ "$WEBSERVER_RUNNING" -gt 0 ]; then
    echo "   ⚠️  Webserver ya está corriendo (se reiniciará)"
else
    echo "   ℹ️  Webserver no está corriendo"
fi

if [ "$SCHEDULER_RUNNING" -gt 0 ]; then
    echo "   ⚠️  Scheduler ya está corriendo (se reiniciará)"
else
    echo "   ℹ️  Scheduler no está corriendo"
fi

echo ""
echo "🛑 Deteniendo procesos existentes..."
pkill -9 -f "airflow webserver" 2>/dev/null || true
pkill -9 -f "airflow scheduler" 2>/dev/null || true
pkill -9 -f "gunicorn.*airflow" 2>/dev/null || true
sleep 3

# Verificar que todos estén detenidos
REMAINING=$(ps aux | grep -E "(airflow|gunicorn)" | grep -v grep | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo "   ⚠️  Aún hay procesos corriendo, forzando detención..."
    pkill -9 -f airflow 2>/dev/null || true
    sleep 2
fi

echo "   ✅ Todos los procesos detenidos"
echo ""

echo "📋 Verificando configuración de Airflow..."
if [ ! -f $AIRFLOW_HOME/airflow.cfg ]; then
    echo "   ⚠️  No se encuentra airflow.cfg, inicializando..."
    airflow db init
fi

# Configurar para no cargar ejemplos
export AIRFLOW__CORE__LOAD_EXAMPLES=False
export AIRFLOW__CORE__DAGS_FOLDER=$AIRFLOW_HOME/dags

echo "   ✅ Configuración verificada"
echo ""

echo "🚀 Iniciando webserver..."
cd $AIRFLOW_HOME
nohup airflow webserver -p 8080 > /tmp/airflow_webserver.log 2>&1 &

echo "   Esperando a que el webserver inicie..."
sleep 15

# Verificar que el webserver esté corriendo
if ps aux | grep -q "[g]unicorn.*airflow"; then
    echo "   ✅ Webserver iniciado correctamente"
    WEBSERVER_PID=$(ps aux | grep "[g]unicorn.*airflow" | grep -v grep | awk '{print $2}' | head -1)
    echo "   PID: $WEBSERVER_PID"
else
    echo "   ❌ Error iniciando webserver"
    echo "   Últimas líneas del log:"
    tail -20 /tmp/airflow_webserver.log
    exit 1
fi

# Verificar que el puerto esté escuchando
if ss -tlnp 2>/dev/null | grep -q ":8080" || netstat -tlnp 2>/dev/null | grep -q ":8080"; then
    echo "   ✅ Puerto 8080 está escuchando"
    if ss -tlnp 2>/dev/null | grep -q ":8080"; then
        ss -tlnp 2>/dev/null | grep 8080
    else
        netstat -tlnp 2>/dev/null | grep 8080
    fi
else
    echo "   ⚠️  Puerto 8080 no está escuchando aún (puede tardar unos segundos más)"
fi

echo ""
echo "🚀 Iniciando scheduler..."
cd $AIRFLOW_HOME
nohup airflow scheduler > /tmp/airflow_scheduler.log 2>&1 &

echo "   Esperando a que el scheduler inicie..."
sleep 10

# Verificar que el scheduler esté corriendo
if ps aux | grep -q "[a]irflow scheduler"; then
    echo "   ✅ Scheduler iniciado correctamente"
    SCHEDULER_PID=$(ps aux | grep "[a]irflow scheduler" | grep -v grep | awk '{print $2}' | head -1)
    echo "   PID: $SCHEDULER_PID"
else
    echo "   ❌ Error iniciando scheduler"
    echo "   Últimas líneas del log:"
    tail -20 /tmp/airflow_scheduler.log
    exit 1
fi

echo ""
echo "📊 Verificando estado final..."
echo ""
echo "   Procesos de Airflow:"
ps aux | grep -E "(airflow|gunicorn)" | grep -v grep | head -5
echo ""
echo "   Puerto 8080:"
if ss -tlnp 2>/dev/null | grep -q ":8080"; then
    ss -tlnp 2>/dev/null | grep 8080
elif netstat -tlnp 2>/dev/null | grep -q ":8080"; then
    netstat -tlnp 2>/dev/null | grep 8080
else
    echo "   (verificando...)"
fi

echo ""
echo "   Verificando respuesta HTTP..."
sleep 5
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/login 2>/dev/null || echo "000")
if [ "$HTTP_RESPONSE" = "200" ]; then
    echo "   ✅ Webserver responde correctamente (HTTP $HTTP_RESPONSE)"
elif [ "$HTTP_RESPONSE" = "000" ]; then
    echo "   ⚠️  Webserver aún no responde (puede tardar unos segundos más)"
else
    echo "   ⚠️  Webserver responde con código: $HTTP_RESPONSE"
fi

echo ""
echo "=========================================="
echo "✅ CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""
echo "📌 Información de acceso:"
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "18.118.31.28")
echo "   URL: http://$PUBLIC_IP:8080"
echo "   Usuario: admin"
echo "   Contraseña: admin"
echo ""
echo "⏳ Espera 20-30 segundos y luego:"
echo "   1. Abre tu navegador y ve a: http://$PUBLIC_IP:8080"
echo "   2. El warning del scheduler debería desaparecer en 1-2 minutos"
echo "   3. Puedes ejecutar el DAG 'recommendations_pipeline'"
echo ""
echo "🔍 Para verificar logs:"
echo "   tail -f /tmp/airflow_webserver.log"
echo "   tail -f /tmp/airflow_scheduler.log"
echo ""


