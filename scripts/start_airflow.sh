#!/bin/bash
# Script para iniciar servicios de Airflow
# Ejecutar DESDE DENTRO de EC2

export AIRFLOW_HOME=~/airflow
source ~/airflow-env/bin/activate

echo "Iniciando servicios de Airflow..."

# Detener servicios anteriores si existen
pkill -f "airflow webserver" || true
pkill -f "airflow scheduler" || true

sleep 2

# Iniciar webserver
echo "Iniciando webserver en puerto 8080..."
airflow webserver -D -p 8080

# Iniciar scheduler
echo "Iniciando scheduler..."
airflow scheduler -D

sleep 3

# Verificar que estén corriendo
if pgrep -f "airflow webserver" > /dev/null && pgrep -f "airflow scheduler" > /dev/null; then
    echo "✅ Servicios de Airflow iniciados correctamente"
    echo ""
    echo "Accede a Airflow UI en: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
    echo "Usuario: admin"
    echo "Password: admin"
else
    echo "⚠️  Error iniciando servicios. Revisa los logs:"
    echo "   tail -f $AIRFLOW_HOME/logs/scheduler/latest/*.log"
    echo "   tail -f $AIRFLOW_HOME/logs/webserver/*.log"
fi



