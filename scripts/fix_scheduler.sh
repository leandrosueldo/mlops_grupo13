#!/bin/bash
# Script para arreglar el scheduler y hacer que procese las tareas

SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"

echo "=========================================="
echo "ARREGLANDO SCHEDULER DE AIRFLOW"
echo "=========================================="

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

echo "1. Deteniendo scheduler existente..."
pkill -9 -f "airflow scheduler" 2>/dev/null || true
sleep 3

echo ""
echo "2. Verificando configuración del executor..."
EXECUTOR=$(grep "^executor" ~/airflow/airflow.cfg 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "SequentialExecutor")
echo "   Executor actual: $EXECUTOR"

if [ "$EXECUTOR" != "LocalExecutor" ] && [ "$EXECUTOR" != "CeleryExecutor" ]; then
    echo "   Cambiando a LocalExecutor para mejor rendimiento..."
    sed -i 's/^executor = .*/executor = LocalExecutor/' ~/airflow/airflow.cfg 2>/dev/null || echo "   No se pudo cambiar, continuando..."
fi

echo ""
echo "3. Iniciando scheduler..."
cd ~/airflow
nohup airflow scheduler -D > /tmp/airflow_scheduler.log 2>&1 &

echo "   Esperando a que inicie..."
sleep 10

if ps aux | grep -q "[a]irflow scheduler"; then
    echo "   ✅ Scheduler iniciado"
    ps aux | grep "[a]irflow scheduler" | head -1
else
    echo "   ❌ Error iniciando scheduler"
    echo "   Revisando logs..."
    tail -20 /tmp/airflow_scheduler.log
    exit 1
fi

echo ""
echo "4. Verificando que el scheduler esté procesando..."
sleep 5
tail -15 /tmp/airflow_scheduler.log | grep -i "scheduler\|dag\|task" | tail -5

echo ""
echo "5. Verificando DAGs disponibles..."
airflow dags list | grep recommendations

echo ""
echo "=========================================="
echo "SCHEDULER CONFIGURADO"
echo "=========================================="
echo "El scheduler ahora debería procesar las tareas."
echo ""
echo "Para verificar:"
echo "1. Refresca la página de Airflow"
echo "2. El warning 'scheduler does not appear to be running' debería desaparecer"
echo "3. Ejecuta el DAG nuevamente"
echo "4. Las tareas deberían pasar de 'queued' a 'running' y luego 'success'"
ENDSSH

echo ""
echo "✅ Proceso completado"
echo "Espera 30 segundos y luego refresca la página de Airflow"
echo "El warning del scheduler debería desaparecer"



