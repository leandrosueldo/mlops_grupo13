#!/bin/bash
# Script para ejecutar el DAG completo y verificar que todo funcione

set -e

echo "=========================================="
echo "EJECUTANDO DAG COMPLETO - VALIDACIÓN"
echo "=========================================="

source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

# 1. Verificar y reiniciar scheduler si es necesario
echo ""
echo "1. Verificando scheduler..."
if ! ps aux | grep -q "[a]irflow scheduler"; then
    echo "   Scheduler no está corriendo. Iniciando..."
    pkill -9 -f "airflow scheduler" 2>/dev/null || true
    sleep 2
    nohup airflow scheduler -D > /tmp/airflow_scheduler.log 2>&1 &
    sleep 5
    echo "   ✅ Scheduler iniciado"
else
    echo "   ✅ Scheduler ya está corriendo"
fi

# 2. Verificar que el DAG esté cargado
echo ""
echo "2. Verificando DAG..."
if airflow dags list | grep -q "recommendations_pipeline"; then
    echo "   ✅ DAG encontrado"
else
    echo "   ❌ DAG no encontrado. Esperando 10 segundos..."
    sleep 10
    if airflow dags list | grep -q "recommendations_pipeline"; then
        echo "   ✅ DAG encontrado después de esperar"
    else
        echo "   ❌ ERROR: DAG aún no está disponible"
        exit 1
    fi
fi

# 3. Limpiar runs anteriores en estado queued
echo ""
echo "3. Limpiando runs anteriores..."
airflow dags delete recommendations_pipeline --yes 2>/dev/null || true
sleep 5

# 4. Trigger nuevo run
echo ""
echo "4. Ejecutando DAG..."
RUN_OUTPUT=$(airflow dags trigger recommendations_pipeline 2>&1)
echo "   $RUN_OUTPUT"

# 5. Obtener el run_id
sleep 5
RUN_ID=$(airflow dags list-runs -d recommendations_pipeline --no-backfill -o plain 2>&1 | tail -1 | awk '{print $2}')
echo "   Run ID: $RUN_ID"

# 6. Monitorear progreso de las tareas
echo ""
echo "5. Monitoreando progreso de tareas..."
MAX_WAIT=300  # 5 minutos máximo
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $MAX_WAIT ]; do
    echo "   Esperando $INTERVAL segundos... ($ELAPSED/$MAX_WAIT)"
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    
    # Verificar estados
    FILTER_STATE=$(airflow tasks state recommendations_pipeline filter_data $RUN_ID 2>&1 || echo "unknown")
    TOPCTR_STATE=$(airflow tasks state recommendations_pipeline top_ctr $RUN_ID 2>&1 || echo "unknown")
    TOPPROD_STATE=$(airflow tasks state recommendations_pipeline top_product $RUN_ID 2>&1 || echo "unknown")
    DB_STATE=$(airflow tasks state recommendations_pipeline db_writing $RUN_ID 2>&1 || echo "unknown")
    
    echo "   filter_data: $FILTER_STATE"
    echo "   top_ctr: $TOPCTR_STATE"
    echo "   top_product: $TOPPROD_STATE"
    echo "   db_writing: $DB_STATE"
    
    # Si todas las tareas están en success, salir
    if [ "$FILTER_STATE" = "success" ] && [ "$TOPCTR_STATE" = "success" ] && [ "$TOPPROD_STATE" = "success" ] && [ "$DB_STATE" = "success" ]; then
        echo ""
        echo "   ✅ TODAS LAS TAREAS COMPLETADAS EXITOSAMENTE"
        break
    fi
    
    # Si alguna tarea falló, salir
    if [ "$FILTER_STATE" = "failed" ] || [ "$TOPCTR_STATE" = "failed" ] || [ "$TOPPROD_STATE" = "failed" ] || [ "$DB_STATE" = "failed" ]; then
        echo ""
        echo "   ❌ ALGUNA TAREA FALLÓ"
        exit 1
    fi
done

# 7. Verificar resultados finales
echo ""
echo "6. Verificando resultados finales..."
FINAL_FILTER=$(airflow tasks state recommendations_pipeline filter_data $RUN_ID 2>&1 || echo "unknown")
FINAL_TOPCTR=$(airflow tasks state recommendations_pipeline top_ctr $RUN_ID 2>&1 || echo "unknown")
FINAL_TOPPROD=$(airflow tasks state recommendations_pipeline top_product $RUN_ID 2>&1 || echo "unknown")
FINAL_DB=$(airflow tasks state recommendations_pipeline db_writing $RUN_ID 2>&1 || echo "unknown")

echo "   Estados finales:"
echo "   - filter_data: $FINAL_FILTER"
echo "   - top_ctr: $FINAL_TOPCTR"
echo "   - top_product: $FINAL_TOPPROD"
echo "   - db_writing: $FINAL_DB"

# 8. Verificar datos en RDS
echo ""
echo "7. Verificando datos en RDS..."
python3 << 'PYEOF'
import psycopg2
try:
    conn = psycopg2.connect(
        host="mimgrupo13.cpomi0gaon83.us-east-2.rds.amazonaws.com",
        port=5432,
        database="mlops",
        user="postgres",
        password="Mimgrupo13",
        sslmode="require"
    )
    cursor = conn.cursor()
    
    cursor.execute("SELECT COUNT(*) FROM recommendations")
    total = cursor.fetchone()[0]
    print(f"   Total recomendaciones: {total}")
    
    cursor.execute("SELECT COUNT(DISTINCT advertiser_id) FROM recommendations")
    advertisers = cursor.fetchone()[0]
    print(f"   Total advertisers: {advertisers}")
    
    cursor.execute("SELECT COUNT(DISTINCT model_name) FROM recommendations")
    models = cursor.fetchone()[0]
    print(f"   Total modelos: {models}")
    
    cursor.execute("""
        SELECT advertiser_id, model_name, COUNT(*) 
        FROM recommendations 
        GROUP BY advertiser_id, model_name 
        HAVING COUNT(*) != 20
    """)
    incorrect = cursor.fetchall()
    if incorrect:
        print(f"   ⚠️  Advertisers con conteo incorrecto: {incorrect}")
    else:
        print("   ✅ Todos los advertisers tienen 20 productos por modelo")
    
    cursor.close()
    conn.close()
    print("   ✅ Conexión a RDS exitosa")
except Exception as e:
    print(f"   ❌ Error verificando RDS: {e}")
    exit(1)
PYEOF

# 9. Resumen final
echo ""
echo "=========================================="
echo "RESUMEN FINAL"
echo "=========================================="
if [ "$FINAL_FILTER" = "success" ] && [ "$FINAL_TOPCTR" = "success" ] && [ "$FINAL_TOPPROD" = "success" ] && [ "$FINAL_DB" = "success" ]; then
    echo "✅ DAG EJECUTADO EXITOSAMENTE"
    echo "✅ Todas las tareas completadas"
    echo "✅ Datos escritos en RDS"
    echo ""
    echo "El sistema está listo para producción"
    exit 0
else
    echo "❌ DAG NO COMPLETÓ EXITOSAMENTE"
    echo "Revisar logs para más detalles"
    exit 1
fi



