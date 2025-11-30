#!/bin/bash
# Script para reiniciar el webserver de Airflow correctamente

SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"

echo "Reiniciando Airflow Webserver..."

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

echo "1. Deteniendo procesos existentes..."
pkill -9 -f "airflow webserver" 2>/dev/null || true
pkill -9 -f "gunicorn.*airflow" 2>/dev/null || true
sleep 3

echo "2. Verificando configuración..."
if [ ! -f ~/airflow/airflow.cfg ]; then
    echo "   Inicializando Airflow..."
    airflow db init
fi

echo "3. Verificando directorio de DAGs..."
if [ ! -d ~/airflow/dags ]; then
    mkdir -p ~/airflow/dags
fi

echo "4. Iniciando webserver..."
cd ~/airflow
export AIRFLOW__CORE__DAGS_FOLDER=~/airflow/dags
nohup airflow webserver -p 8080 > /tmp/airflow_webserver.log 2>&1 &

echo "5. Esperando a que inicie..."
sleep 15

echo "6. Verificando estado..."
if ps aux | grep -q "[g]unicorn.*airflow"; then
    echo "   ✅ Webserver corriendo"
    ps aux | grep "[g]unicorn.*airflow" | head -1
else
    echo "   ❌ Webserver no está corriendo"
    echo "   Revisando logs..."
    tail -20 /tmp/airflow_webserver.log
fi

echo ""
echo "7. Verificando puerto..."
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
echo "=== RESUMEN ==="
echo "Webserver: http://18.118.31.28:8080"
echo "Usuario: admin"
echo "Contraseña: admin"
echo ""
echo "Si no puedes acceder, verifica el Security Group de EC2"
echo "debe tener una regla de entrada para el puerto 8080"
ENDSSH

echo ""
echo "✅ Proceso completado"
echo "Espera 10-15 segundos y luego intenta acceder a: http://18.118.31.28:8080"



