#!/bin/bash
# Script simplificado para verificar y ejecutar el DAG

SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"

echo "=== VERIFICACIÓN Y EJECUCIÓN DEL DAG ==="
echo ""

# 1. Verificar scheduler
echo "1. Verificando scheduler..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" 'ps aux | grep "[a]irflow scheduler" | head -1' && echo "   ✅ Scheduler corriendo" || echo "   ⚠️  Scheduler no encontrado"

# 2. Verificar DAG
echo ""
echo "2. Verificando DAG..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" 'source ~/airflow-env/bin/activate && export AIRFLOW_HOME=~/airflow && airflow dags list | grep recommendations' && echo "   ✅ DAG encontrado" || echo "   ❌ DAG no encontrado"

# 3. Ejecutar DAG
echo ""
echo "3. Ejecutando DAG..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" 'source ~/airflow-env/bin/activate && export AIRFLOW_HOME=~/airflow && airflow dags trigger recommendations_pipeline 2>&1'

# 4. Esperar y verificar estados
echo ""
echo "4. Esperando 30 segundos para que las tareas se ejecuten..."
sleep 30

echo ""
echo "5. Verificando estados de tareas..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" 'source ~/airflow-env/bin/activate && export AIRFLOW_HOME=~/airflow && RUN_ID=$(airflow dags list-runs -d recommendations_pipeline --no-backfill -o plain 2>&1 | tail -1 | awk "{print \$2}") && echo "Run ID: $RUN_ID" && for task in filter_data top_ctr top_product db_writing; do echo -n "$task: "; airflow tasks state recommendations_pipeline $task $RUN_ID 2>&1; done'

# 6. Verificar datos en RDS
echo ""
echo "6. Verificando datos en RDS..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" 'python3 << "EOF"
import psycopg2
try:
    conn = psycopg2.connect(host="mimgrupo13.cpomi0gaon83.us-east-2.rds.amazonaws.com", port=5432, database="mlops", user="postgres", password="Mimgrupo13", sslmode="require")
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM recommendations")
    total = cursor.fetchone()[0]
    cursor.execute("SELECT COUNT(DISTINCT advertiser_id) FROM recommendations")
    advertisers = cursor.fetchone()[0]
    print(f"   Total recomendaciones: {total}")
    print(f"   Total advertisers: {advertisers}")
    cursor.close()
    conn.close()
    print("   ✅ RDS funcionando correctamente")
except Exception as e:
    print(f"   ❌ Error: {e}")
EOF
'

# 7. Verificar API
echo ""
echo "7. Verificando API..."
curl -s http://18.118.31.28:8000/health | python3 -m json.tool && echo "   ✅ API funcionando" || echo "   ❌ API no responde"

echo ""
echo "=== VERIFICACIÓN COMPLETA ==="



