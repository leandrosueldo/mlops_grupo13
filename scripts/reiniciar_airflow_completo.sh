#!/bin/bash
# Script para reiniciar completamente Airflow (webserver y scheduler)

SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"

echo "=========================================="
echo "REINICIANDO AIRFLOW COMPLETAMENTE"
echo "=========================================="

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

echo "1. Deteniendo todos los procesos de Airflow..."
pkill -9 -f "airflow webserver" 2>/dev/null || true
pkill -9 -f "airflow scheduler" 2>/dev/null || true
pkill -9 -f "gunicorn.*airflow" 2>/dev/null || true
sleep 5

echo ""
echo "2. Verificando que todos los procesos estén detenidos..."
if ps aux | grep -E "(airflow|gunicorn)" | grep -v grep; then
    echo "   ⚠️  Aún hay procesos corriendo, forzando detención..."
    pkill -9 -f airflow
    sleep 3
else
    echo "   ✅ Todos los procesos detenidos"
fi

echo ""
echo "3. Iniciando webserver..."
cd ~/airflow
export AIRFLOW__CORE__LOAD_EXAMPLES=False
nohup airflow webserver -p 8080 > /tmp/airflow_webserver.log 2>&1 &

echo "   Esperando a que inicie..."
sleep 10

if ps aux | grep -q "[g]unicorn.*airflow"; then
    echo "   ✅ Webserver iniciado"
    ps aux | grep "[g]unicorn.*airflow" | head -1
else
    echo "   ❌ Error iniciando webserver"
    echo "   Revisando logs..."
    tail -20 /tmp/airflow_webserver.log
fi

echo ""
echo "4. Verificando puerto 8080..."
if ss -tlnp 2>/dev/null | grep -q ":8080"; then
    echo "   ✅ Puerto 8080 está escuchando"
    ss -tlnp 2>/dev/null | grep 8080
elif netstat -tlnp 2>/dev/null | grep -q ":8080"; then
    echo "   ✅ Puerto 8080 está escuchando"
    netstat -tlnp 2>/dev/null | grep 8080
else
    echo "   ⚠️  Puerto 8080 no está escuchando"
fi

echo ""
echo "5. Iniciando scheduler..."
cd ~/airflow
nohup airflow scheduler > /tmp/airflow_scheduler.log 2>&1 &

echo "   Esperando a que inicie..."
sleep 10

if ps aux | grep -q "[a]irflow scheduler"; then
    echo "   ✅ Scheduler iniciado"
    ps aux | grep "[a]irflow scheduler" | head -1
    echo ""
    echo "   Revisando logs iniciales..."
    tail -10 /tmp/airflow_scheduler.log | grep -E "(INFO|ERROR|WARNING)" | tail -3
else
    echo "   ❌ Error iniciando scheduler"
    echo "   Revisando logs..."
    tail -20 /tmp/airflow_scheduler.log
fi

echo ""
echo "=========================================="
echo "RESUMEN"
echo "=========================================="
echo "Webserver: http://18.118.31.28:8080"
echo "Usuario: admin"
echo "Contraseña: admin"
echo ""
echo "Estado de procesos:"
ps aux | grep -E "(airflow|gunicorn)" | grep -v grep | head -3
echo ""
echo "Espera 30 segundos y luego:"
echo "1. Refresca la página de Airflow"
echo "2. El warning del scheduler debería desaparecer después de 1-2 minutos"
echo "3. Ejecuta el DAG nuevamente"
ENDSSH

echo ""
echo "✅ Proceso completado"
echo "Espera 30 segundos y accede a: http://18.118.31.28:8080"



