#!/bin/bash
# Script para poner Airflow y App Runner en producción

SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"

echo "=========================================="
echo "PONIENDO SISTEMA EN PRODUCCIÓN"
echo "=========================================="

# 1. Detener servicios de Airflow
echo ""
echo "1. Deteniendo servicios de Airflow..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

# Detener webserver y scheduler
pkill -9 -f "airflow webserver" 2>/dev/null || true
pkill -9 -f "airflow scheduler" 2>/dev/null || true
pkill -9 -f "gunicorn.*airflow" 2>/dev/null || true
sleep 2
echo "   ✅ Servicios detenidos"
ENDSSH

# 2. Iniciar scheduler
echo ""
echo "2. Iniciando scheduler de Airflow..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

# Iniciar scheduler
nohup airflow scheduler -D > /tmp/airflow_scheduler.log 2>&1 &
sleep 3
ps aux | grep "[a]irflow scheduler" | head -1 && echo "   ✅ Scheduler iniciado" || echo "   ❌ Error iniciando scheduler"
ENDSSH

# 3. Iniciar webserver
echo ""
echo "3. Iniciando webserver de Airflow..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

# Iniciar webserver
nohup airflow webserver -D > /tmp/airflow_webserver.log 2>&1 &
sleep 5
ps aux | grep "[g]unicorn.*airflow" | head -1 && echo "   ✅ Webserver iniciado" || echo "   ⚠️  Webserver puede estar iniciando..."
ENDSSH

# 4. Verificar que el DAG esté cargado
echo ""
echo "4. Verificando DAG..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow

sleep 5
if airflow dags list | grep -q "recommendations_pipeline"; then
    echo "   ✅ DAG cargado correctamente"
    airflow dags list | grep recommendations
else
    echo "   ⚠️  DAG no encontrado, esperando 10 segundos más..."
    sleep 10
    if airflow dags list | grep -q "recommendations_pipeline"; then
        echo "   ✅ DAG cargado"
    else
        echo "   ❌ DAG aún no disponible"
    fi
fi
ENDSSH

# 5. Verificar API
echo ""
echo "5. Verificando API..."
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://18.118.31.28:8000/health 2>/dev/null || echo "000")
if [ "$API_STATUS" = "200" ]; then
    echo "   ✅ API funcionando (http://18.118.31.28:8000)"
    curl -s http://18.118.31.28:8000/health | python3 -m json.tool 2>/dev/null || echo "   Respuesta recibida"
else
    echo "   ⚠️  API no responde (código: $API_STATUS)"
    echo "   Verificando si el contenedor está corriendo..."
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" 'docker ps | grep -E "(api|8000)" || ps aux | grep "[u]vicorn"'
fi

# 6. Configurar App Runner
echo ""
echo "6. Configurando App Runner..."
echo "   Verificando imagen en ECR..."

# Verificar si la imagen existe en ECR
ECR_REPO="396913735447.dkr.ecr.us-east-2.amazonaws.com/grupo13-recommendations-api"
aws ecr describe-images --repository-name grupo13-recommendations-api --region us-east-2 2>/dev/null | grep -q "imageTags" && echo "   ✅ Imagen encontrada en ECR" || echo "   ⚠️  Imagen no encontrada en ECR"

# Verificar servicio de App Runner
APP_RUNNER_SERVICE=$(aws apprunner list-services --region us-east-2 2>/dev/null | grep -o '"ServiceName": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "")
if [ -n "$APP_RUNNER_SERVICE" ]; then
    echo "   ✅ Servicio App Runner encontrado: $APP_RUNNER_SERVICE"
    APP_RUNNER_STATUS=$(aws apprunner describe-service --service-arn $(aws apprunner list-services --region us-east-2 --query "ServiceSummaryList[?ServiceName=='$APP_RUNNER_SERVICE'].ServiceArn" --output text) --region us-east-2 2>/dev/null | grep -o '"Status": "[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
    echo "   Estado: $APP_RUNNER_STATUS"
else
    echo "   ⚠️  Servicio App Runner no encontrado"
    echo "   Para crear el servicio, ejecuta:"
    echo "   aws apprunner create-service --cli-input-json file://apprunner-config.json --region us-east-2"
fi

# 7. Resumen final
echo ""
echo "=========================================="
echo "RESUMEN"
echo "=========================================="
echo "Airflow Webserver: http://18.118.31.28:8080"
echo "   Usuario: admin"
echo "   Contraseña: admin"
echo ""
echo "API: http://18.118.31.28:8000"
echo "   Health: http://18.118.31.28:8000/health"
echo ""
echo "DAG: recommendations_pipeline"
echo "   Puede ejecutarse desde la UI de Airflow"
echo ""
echo "=========================================="



