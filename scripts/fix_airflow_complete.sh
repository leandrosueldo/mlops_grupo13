#!/bin/bash
# Script completo para solucionar problemas de Airflow (acceso y scheduler)
# Ejecutar desde tu máquina local

set -e  # Salir si hay error

# Configuración
SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"
EC2_IP="18.118.31.28"
REGION="us-east-2"

echo "=========================================="
echo "🔧 SOLUCIONANDO PROBLEMAS DE AIRFLOW"
echo "=========================================="
echo ""

# Verificar que existe la clave SSH
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ Error: No se encuentra la clave SSH en: $SSH_KEY"
    echo "   Por favor, verifica la ruta de tu clave .pem"
    exit 1
fi

# Dar permisos correctos a la clave
chmod 400 "$SSH_KEY" 2>/dev/null || true

echo "📋 Paso 1: Verificando Security Group de EC2..."
echo ""

# Obtener Instance ID y Security Group ID
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=ip-address,Values=$EC2_IP" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ]; then
    echo "⚠️  No se pudo obtener el Instance ID automáticamente"
    echo "   Continuando con la configuración manual..."
else
    echo "   ✅ Instance ID: $INSTANCE_ID"
    
    SG_ID=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --region $REGION \
        --query "Reservations[*].Instances[*].SecurityGroups[0].GroupId" \
        --output text 2>/dev/null || echo "")
    
    if [ ! -z "$SG_ID" ]; then
        echo "   ✅ Security Group ID: $SG_ID"
        
        # Verificar si ya existe la regla para el puerto 8080
        PORT_8080_EXISTS=$(aws ec2 describe-security-groups \
            --group-ids $SG_ID \
            --region $REGION \
            --query "SecurityGroups[0].IpPermissions[?FromPort==\`8080\`]" \
            --output text 2>/dev/null || echo "")
        
        if [ -z "$PORT_8080_EXISTS" ]; then
            echo "   ⚠️  Puerto 8080 no está abierto en el Security Group"
            echo "   🔧 Agregando regla para puerto 8080..."
            
            aws ec2 authorize-security-group-ingress \
                --group-id $SG_ID \
                --protocol tcp \
                --port 8080 \
                --cidr 0.0.0.0/0 \
                --region $REGION 2>/dev/null && echo "   ✅ Regla agregada exitosamente" || echo "   ⚠️  Error agregando regla (puede que ya exista)"
        else
            echo "   ✅ Puerto 8080 ya está abierto en el Security Group"
        fi
    fi
fi

echo ""
echo "📋 Paso 2: Conectando a EC2 y verificando estado actual..."
echo ""

# Ejecutar comandos en EC2
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$EC2_HOST" << 'ENDSSH'
set -e

echo "   Verificando entorno de Airflow..."
export AIRFLOW_HOME=~/airflow

# Verificar si existe el entorno virtual
if [ ! -d ~/airflow-env ]; then
    echo "   ❌ No se encuentra el entorno virtual de Airflow"
    echo "   Por favor, ejecuta primero el script de instalación"
    exit 1
fi

# Activar entorno virtual
source ~/airflow-env/bin/activate

# Verificar instalación de Airflow
if ! command -v airflow &> /dev/null; then
    echo "   ❌ Airflow no está instalado"
    exit 1
fi

echo "   ✅ Entorno de Airflow verificado"
echo ""

echo "   Verificando procesos actuales..."
WEBSERVER_RUNNING=$(ps aux | grep -E "[g]unicorn.*airflow" | wc -l)
SCHEDULER_RUNNING=$(ps aux | grep -E "[a]irflow scheduler" | grep -v grep | wc -l)

if [ "$WEBSERVER_RUNNING" -gt 0 ]; then
    echo "   ⚠️  Webserver ya está corriendo (se reiniciará)"
else
    echo "   ℹ️  Webserver no está corriendo"
fi

if [ "$SCHEDULER_RUNNING" -gt 0 ]; then
    echo "   ⚠️  Scheduler ya está corriendo (se reiniciará)"
else
    echo "   ℹ️  Scheduler no está corriendo"
fi

echo ""
echo "   Deteniendo procesos existentes..."
pkill -9 -f "airflow webserver" 2>/dev/null || true
pkill -9 -f "airflow scheduler" 2>/dev/null || true
pkill -9 -f "gunicorn.*airflow" 2>/dev/null || true
sleep 3

# Verificar que todos estén detenidos
REMAINING=$(ps aux | grep -E "(airflow|gunicorn)" | grep -v grep | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo "   ⚠️  Aún hay procesos corriendo, forzando detención..."
    pkill -9 -f airflow 2>/dev/null || true
    sleep 2
fi

echo "   ✅ Todos los procesos detenidos"
echo ""

echo "   Verificando configuración de Airflow..."
if [ ! -f $AIRFLOW_HOME/airflow.cfg ]; then
    echo "   ⚠️  No se encuentra airflow.cfg, inicializando..."
    airflow db init
fi

# Configurar para no cargar ejemplos
export AIRFLOW__CORE__LOAD_EXAMPLES=False
export AIRFLOW__CORE__DAGS_FOLDER=$AIRFLOW_HOME/dags

echo "   ✅ Configuración verificada"
echo ""

echo "   Iniciando webserver..."
cd $AIRFLOW_HOME
nohup airflow webserver -p 8080 > /tmp/airflow_webserver.log 2>&1 &

echo "   Esperando a que el webserver inicie..."
sleep 15

# Verificar que el webserver esté corriendo
if ps aux | grep -q "[g]unicorn.*airflow"; then
    echo "   ✅ Webserver iniciado correctamente"
    WEBSERVER_PID=$(ps aux | grep "[g]unicorn.*airflow" | grep -v grep | awk '{print $2}' | head -1)
    echo "   PID: $WEBSERVER_PID"
else
    echo "   ❌ Error iniciando webserver"
    echo "   Últimas líneas del log:"
    tail -20 /tmp/airflow_webserver.log
    exit 1
fi

# Verificar que el puerto esté escuchando
if ss -tlnp 2>/dev/null | grep -q ":8080" || netstat -tlnp 2>/dev/null | grep -q ":8080"; then
    echo "   ✅ Puerto 8080 está escuchando"
else
    echo "   ⚠️  Puerto 8080 no está escuchando aún (puede tardar unos segundos más)"
fi

echo ""
echo "   Iniciando scheduler..."
cd $AIRFLOW_HOME
nohup airflow scheduler > /tmp/airflow_scheduler.log 2>&1 &

echo "   Esperando a que el scheduler inicie..."
sleep 10

# Verificar que el scheduler esté corriendo
if ps aux | grep -q "[a]irflow scheduler"; then
    echo "   ✅ Scheduler iniciado correctamente"
    SCHEDULER_PID=$(ps aux | grep "[a]irflow scheduler" | grep -v grep | awk '{print $2}' | head -1)
    echo "   PID: $SCHEDULER_PID"
else
    echo "   ❌ Error iniciando scheduler"
    echo "   Últimas líneas del log:"
    tail -20 /tmp/airflow_scheduler.log
    exit 1
fi

echo ""
echo "   Verificando estado final..."
echo ""
echo "   Procesos de Airflow:"
ps aux | grep -E "(airflow|gunicorn)" | grep -v grep | head -5
echo ""
echo "   Puerto 8080:"
ss -tlnp 2>/dev/null | grep 8080 || netstat -tlnp 2>/dev/null | grep 8080 || echo "   (verificando...)"

echo ""
echo "   ✅ Servicios de Airflow iniciados correctamente"
ENDSSH

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ CONFIGURACIÓN COMPLETADA"
    echo "=========================================="
    echo ""
    echo "📌 Información de acceso:"
    echo "   URL: http://$EC2_IP:8080"
    echo "   Usuario: admin"
    echo "   Contraseña: admin"
    echo ""
    echo "⏳ Espera 20-30 segundos y luego:"
    echo "   1. Abre tu navegador y ve a: http://$EC2_IP:8080"
    echo "   2. El warning del scheduler debería desaparecer en 1-2 minutos"
    echo "   3. Puedes ejecutar el DAG 'recommendations_pipeline'"
    echo ""
    echo "🔍 Para verificar logs en EC2:"
    echo "   ssh -i $SSH_KEY $EC2_HOST"
    echo "   tail -f /tmp/airflow_webserver.log"
    echo "   tail -f /tmp/airflow_scheduler.log"
    echo ""
else
    echo ""
    echo "❌ Error durante la configuración"
    echo "   Revisa los mensajes de error arriba"
    exit 1
fi


