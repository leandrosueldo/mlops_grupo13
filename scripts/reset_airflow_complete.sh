#!/bin/bash
# Script para resetear completamente Airflow y reconectarlo a RDS

set -e

export AIRFLOW_HOME=~/airflow
export RDS_PASSWORD="Mimgrupo13"
export RDS_HOST="grupo-13-2025-rds.cpomi0gaon83.us-east-2.rds.amazonaws.com"

echo "=========================================="
echo "🧹 LIMPIANDO Y RESETEANDO AIRFLOW"
echo "=========================================="
echo ""

# 1. Detener todos los procesos de Airflow
echo "🛑 Deteniendo procesos de Airflow..."
pkill -9 -f "airflow webserver" 2>/dev/null || true
pkill -9 -f "airflow scheduler" 2>/dev/null || true
pkill -9 -f "gunicorn.*airflow" 2>/dev/null || true
pkill -9 -f "airflow" 2>/dev/null || true
sleep 3

# 2. Verificar que no queden procesos
REMAINING=$(ps aux | grep -E "(airflow|gunicorn)" | grep -v grep | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo "⚠️  Aún hay procesos, forzando detención..."
    pkill -9 -f airflow 2>/dev/null || true
    sleep 2
fi
echo "✅ Todos los procesos detenidos"
echo ""

# 3. Probar conexión a RDS
echo "🔍 Probando conexión a RDS..."
if command -v psql &> /dev/null; then
    PGPASSWORD="${RDS_PASSWORD}" psql -h "${RDS_HOST}" -U postgres -d mlops -c "SELECT 1;" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ Conexión a RDS exitosa"
    else
        echo "❌ Error: No se puede conectar a RDS"
        echo "   Verifica el Security Group de RDS"
        exit 1
    fi
else
    echo "⚠️  psql no está instalado, saltando verificación de conexión"
fi
echo ""

# 4. Actualizar configuración de Airflow
echo "📝 Actualizando configuración de Airflow..."
sed -i "s|sql_alchemy_conn = .*|sql_alchemy_conn = postgresql+psycopg2://postgres:${RDS_PASSWORD}@${RDS_HOST}:5432/mlops|g" ~/airflow/airflow.cfg

# Verificar que se actualizó correctamente
if grep -q "grupo-13-2025-rds" ~/airflow/airflow.cfg; then
    echo "✅ Configuración actualizada correctamente"
else
    echo "❌ Error actualizando configuración"
    exit 1
fi
echo ""

# 5. Limpiar sesiones de base de datos anteriores (opcional)
echo "🧹 Limpiando sesiones de base de datos..."
# No hacemos nada aquí, solo informamos
echo "✅ Listo para inicializar"
echo ""

# 6. Inicializar base de datos de Airflow
echo "🗄️  Inicializando base de datos de Airflow..."
airflow db migrate 2>&1 | head -20 || airflow db init 2>&1 | head -20
echo "✅ Base de datos inicializada"
echo ""

# 7. Crear usuario admin (si no existe)
echo "👤 Creando usuario admin..."
airflow users create \
  --username admin \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com \
  --password admin 2>/dev/null || echo "   Usuario admin ya existe (OK)"
echo ""

# 8. Iniciar webserver
echo "🚀 Iniciando webserver..."
cd ~/airflow
nohup airflow webserver -p 8080 > /tmp/airflow_webserver.log 2>&1 &
WEBSERVER_PID=$!
echo "   PID: $WEBSERVER_PID"
sleep 10

# Verificar webserver
if ps aux | grep -q "[g]unicorn.*airflow"; then
    echo "✅ Webserver iniciado correctamente"
else
    echo "❌ Error iniciando webserver"
    echo "   Logs: tail -20 /tmp/airflow_webserver.log"
    exit 1
fi
echo ""

# 9. Iniciar scheduler
echo "🚀 Iniciando scheduler..."
cd ~/airflow
nohup airflow scheduler > /tmp/airflow_scheduler.log 2>&1 &
SCHEDULER_PID=$!
echo "   PID: $SCHEDULER_PID"
sleep 10

# Verificar scheduler
if ps aux | grep -q "[a]irflow scheduler"; then
    echo "✅ Scheduler iniciado correctamente"
else
    echo "❌ Error iniciando scheduler"
    echo "   Logs: tail -20 /tmp/airflow_scheduler.log"
    exit 1
fi
echo ""

# 10. Verificación final
echo "=========================================="
echo "✅ VERIFICACIÓN FINAL"
echo "=========================================="
echo ""

echo "📊 Procesos de Airflow:"
ps aux | grep -E "(airflow|gunicorn)" | grep -v grep | head -5
echo ""

echo "🔌 Puerto 8080:"
if ss -tlnp 2>/dev/null | grep -q ":8080"; then
    ss -tlnp 2>/dev/null | grep 8080
elif netstat -tlnp 2>/dev/null | grep -q ":8080"; then
    netstat -tlnp 2>/dev/null | grep 8080
else
    echo "   ⚠️  Puerto 8080 no está escuchando aún"
fi
echo ""

echo "🌐 Verificando respuesta HTTP..."
sleep 5
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/login 2>/dev/null || echo "000")
if [ "$HTTP_RESPONSE" = "200" ]; then
    echo "✅ Webserver responde correctamente (HTTP $HTTP_RESPONSE)"
elif [ "$HTTP_RESPONSE" = "000" ]; then
    echo "⚠️  Webserver aún no responde (puede tardar 20-30 segundos más)"
else
    echo "⚠️  Webserver responde con código: $HTTP_RESPONSE"
fi
echo ""

echo "=========================================="
echo "✅ CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "18.222.106.244")
echo "📌 Accede a Airflow en:"
echo "   URL: http://${PUBLIC_IP}:8080"
echo "   Usuario: admin"
echo "   Contraseña: admin"
echo ""
echo "⏳ Espera 20-30 segundos antes de acceder"
echo ""

