#!/bin/bash
# Script para ejecutar directamente en EC2 si ya estás conectado
# O si tienes acceso por AWS Systems Manager Session Manager

echo "=========================================="
echo "🔧 SOLUCIÓN DE AIRFLOW (SIN SSH EXTERNO)"
echo "=========================================="
echo ""
echo "Este script debe ejecutarse DIRECTAMENTE en EC2"
echo "Si ya estás conectado por SSH, ejecuta estos comandos:"
echo ""

cat << 'EOF'
# Activar entorno
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

# Detener procesos antiguos
echo "Deteniendo procesos antiguos..."
pkill -9 -f "airflow webserver" 2>/dev/null || true
pkill -9 -f "airflow scheduler" 2>/dev/null || true
pkill -9 -f "gunicorn.*airflow" 2>/dev/null || true
sleep 3

# Verificar que estén detenidos
REMAINING=$(ps aux | grep -E "(airflow|gunicorn)" | grep -v grep | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo "Forzando detención..."
    pkill -9 -f airflow 2>/dev/null || true
    sleep 2
fi

echo "✅ Procesos detenidos"
echo ""

# Configurar variables
export AIRFLOW__CORE__LOAD_EXAMPLES=False
export AIRFLOW__CORE__DAGS_FOLDER=~/airflow/dags

# Verificar configuración
if [ ! -f $AIRFLOW_HOME/airflow.cfg ]; then
    echo "Inicializando Airflow..."
    airflow db init
fi

echo "Iniciando webserver..."
cd $AIRFLOW_HOME
nohup airflow webserver -p 8080 > /tmp/airflow_webserver.log 2>&1 &
WEBSERVER_PID=$!
echo "Webserver PID: $WEBSERVER_PID"
sleep 15

# Verificar webserver
if ps aux | grep -q "[g]unicorn.*airflow"; then
    echo "✅ Webserver iniciado"
else
    echo "❌ Error iniciando webserver"
    tail -20 /tmp/airflow_webserver.log
    exit 1
fi

echo ""
echo "Iniciando scheduler..."
nohup airflow scheduler > /tmp/airflow_scheduler.log 2>&1 &
SCHEDULER_PID=$!
echo "Scheduler PID: $SCHEDULER_PID"
sleep 10

# Verificar scheduler
if ps aux | grep -q "[a]irflow scheduler"; then
    echo "✅ Scheduler iniciado"
else
    echo "❌ Error iniciando scheduler"
    tail -20 /tmp/airflow_scheduler.log
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""
echo "Verificando estado..."
ps aux | grep -E "(airflow|gunicorn)" | grep -v grep | head -5
echo ""
ss -tlnp 2>/dev/null | grep 8080 || netstat -tlnp 2>/dev/null | grep 8080 || echo "Puerto 8080 verificando..."
echo ""
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "18.118.31.28")
echo "Accede a: http://$PUBLIC_IP:8080"
echo "Usuario: admin"
echo "Contraseña: admin"
EOF


