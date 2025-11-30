#!/bin/bash
# Script para verificar el progreso de la instalación en EC2

EC2_IP="18.118.31.28"
KEY_PATH="$HOME/Downloads/airflow-grupo13-key.pem"

echo "Verificando estado de la instalación en EC2..."
echo ""

# Verificar si Airflow está instalado
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ec2-user@${EC2_IP} << 'EOF'
echo "=== Estado de la Instalación ==="
echo ""

# Verificar Python
if command -v python3 &> /dev/null; then
    echo "✅ Python3 instalado: $(python3 --version)"
else
    echo "❌ Python3 no instalado"
fi

# Verificar AWS CLI
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI instalado: $(aws --version | head -1)"
else
    echo "❌ AWS CLI no instalado"
fi

# Verificar entorno virtual
if [ -d ~/airflow-env ]; then
    echo "✅ Entorno virtual creado"
else
    echo "❌ Entorno virtual no creado"
fi

# Verificar Airflow
if [ -f ~/airflow-env/bin/airflow ]; then
    echo "✅ Airflow instalado"
    source ~/airflow-env/bin/activate
    echo "   Versión: $(airflow version 2>/dev/null | head -1 || echo 'No disponible')"
else
    echo "❌ Airflow no instalado"
fi

# Verificar configuración de Airflow
if [ -f ~/airflow/airflow.cfg ]; then
    echo "✅ Airflow configurado"
    if grep -q "postgresql" ~/airflow/airflow.cfg; then
        echo "✅ Conexión a PostgreSQL configurada"
    else
        echo "⚠️  Conexión a PostgreSQL no configurada"
    fi
else
    echo "❌ Airflow no configurado"
fi

# Verificar servicios corriendo
echo ""
echo "=== Servicios de Airflow ==="
if pgrep -f "airflow webserver" > /dev/null; then
    echo "✅ Webserver corriendo (PID: $(pgrep -f 'airflow webserver'))"
else
    echo "❌ Webserver no está corriendo"
fi

if pgrep -f "airflow scheduler" > /dev/null; then
    echo "✅ Scheduler corriendo (PID: $(pgrep -f 'airflow scheduler'))"
else
    echo "❌ Scheduler no está corriendo"
fi

# Verificar conexión a RDS
echo ""
echo "=== Conexión a RDS ==="
if python3 -c "import psycopg2; conn = psycopg2.connect(host='mimgrupo13.cpomi0gaon83.us-east-2.rds.amazonaws.com', port=5432, database='mlops', user='postgres', password='Mimgrupo13', connect_timeout=5); print('✅ Conexión a RDS exitosa'); conn.close()" 2>/dev/null; then
    echo "✅ Conexión a RDS exitosa"
else
    echo "❌ No se puede conectar a RDS"
fi

echo ""
echo "=== Archivos Importantes ==="
if [ -f ~/airflow/dags/recommendations_pipeline.py ]; then
    echo "✅ DAG encontrado"
else
    echo "❌ DAG no encontrado"
fi

if [ -d ~/airflow/scripts ]; then
    echo "✅ Scripts encontrados"
else
    echo "❌ Scripts no encontrados"
fi
EOF



