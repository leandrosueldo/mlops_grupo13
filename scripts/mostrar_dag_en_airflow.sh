#!/bin/bash
# Script para asegurar que el DAG aparezca en Airflow

SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"

echo "=========================================="
echo "CONFIGURANDO DAG PARA QUE APAREZCA EN AIRFLOW"
echo "=========================================="

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

echo "1. Verificando que el archivo DAG exista..."
if [ -f ~/airflow/dags/recommendations_pipeline.py ]; then
    echo "   ✅ Archivo DAG encontrado"
    ls -lh ~/airflow/dags/recommendations_pipeline.py
else
    echo "   ❌ Archivo DAG no encontrado"
    exit 1
fi

echo ""
echo "2. Verificando sintaxis del DAG..."
python3 -m py_compile ~/airflow/dags/recommendations_pipeline.py 2>&1
if [ $? -eq 0 ]; then
    echo "   ✅ Sintaxis correcta"
else
    echo "   ❌ Error de sintaxis"
    exit 1
fi

echo ""
echo "3. Reiniciando scheduler..."
pkill -9 -f "airflow scheduler" 2>/dev/null || true
sleep 2
nohup airflow scheduler -D > /tmp/airflow_scheduler.log 2>&1 &
sleep 5

if ps aux | grep -q "[a]irflow scheduler"; then
    echo "   ✅ Scheduler reiniciado"
else
    echo "   ❌ Error iniciando scheduler"
    exit 1
fi

echo ""
echo "4. Forzando recarga de DAGs..."
airflow dags reserialize 2>&1 | tail -3

echo ""
echo "5. Esperando a que el scheduler cargue los DAGs..."
sleep 15

echo ""
echo "6. Verificando que el DAG esté disponible..."
if airflow dags list | grep -q "recommendations_pipeline"; then
    echo "   ✅ DAG encontrado en la lista"
    airflow dags list | grep recommendations
else
    echo "   ⚠️  DAG no encontrado aún, esperando más..."
    sleep 10
    if airflow dags list | grep -q "recommendations_pipeline"; then
        echo "   ✅ DAG encontrado después de esperar"
        airflow dags list | grep recommendations
    else
        echo "   ❌ DAG aún no disponible"
        echo "   Revisando logs del scheduler..."
        tail -20 /tmp/airflow_scheduler.log
    fi
fi

echo ""
echo "7. Verificando estado del DAG..."
if airflow dags list | grep -q "recommendations_pipeline"; then
    DAG_STATE=$(airflow dags list | grep recommendations_pipeline | awk '{print $NF}')
    echo "   Estado: $DAG_STATE"
    if [ "$DAG_STATE" = "None" ] || [ "$DAG_STATE" = "False" ]; then
        echo "   ⚠️  DAG está pausado"
        echo "   Para activarlo, ve a la UI de Airflow y activa el toggle"
    else
        echo "   ✅ DAG está activo"
    fi
fi

echo ""
echo "=========================================="
echo "RESUMEN"
echo "=========================================="
echo "1. Refresca la página de Airflow en tu navegador"
echo "2. Busca 'recommendations_pipeline' en la lista"
echo "3. Si no aparece, espera 30 segundos y refresca nuevamente"
echo "4. Si el DAG está pausado (toggle gris), actívalo"
echo ""
echo "URL: http://18.118.31.28:8080"
ENDSSH

echo ""
echo "✅ Proceso completado"
echo "Refresca la página de Airflow y busca 'recommendations_pipeline'"



