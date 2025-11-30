#!/bin/bash
# Script automatizado para solucionar problemas de Airflow
# Este script intenta todo automáticamente

set -e

EC2_IP="18.118.31.28"
SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@$EC2_IP"

echo "=========================================="
echo "🚀 SOLUCIÓN AUTOMATIZADA DE AIRFLOW"
echo "=========================================="
echo ""

# Verificar clave SSH
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ No se encuentra la clave SSH: $SSH_KEY"
    exit 1
fi

chmod 400 "$SSH_KEY" 2>/dev/null || true

echo "📋 Paso 1: Subiendo script de solución a EC2..."
echo ""

# Intentar subir el script
if scp -i "$SSH_KEY" -o ConnectTimeout=15 -o StrictHostKeyChecking=no \
    "$(dirname "$0")/fix_airflow_on_ec2.sh" \
    "$EC2_HOST:~/fix_airflow.sh" 2>/dev/null; then
    echo "   ✅ Script subido exitosamente"
else
    echo "   ⚠️  No se pudo subir el script automáticamente"
    echo ""
    echo "   Por favor, ejecuta manualmente estos comandos:"
    echo ""
    echo "   1. Subir el script:"
    echo "      scp -i $SSH_KEY scripts/fix_airflow_on_ec2.sh $EC2_HOST:~/fix_airflow.sh"
    echo ""
    echo "   2. Conectarte a EC2:"
    echo "      ssh -i $SSH_KEY $EC2_HOST"
    echo ""
    echo "   3. Ejecutar el script:"
    echo "      chmod +x ~/fix_airflow.sh"
    echo "      ~/fix_airflow.sh"
    echo ""
    exit 1
fi

echo ""
echo "📋 Paso 2: Ejecutando script en EC2..."
echo ""

# Ejecutar el script en EC2
ssh -i "$SSH_KEY" -o ConnectTimeout=15 -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
chmod +x ~/fix_airflow.sh
~/fix_airflow.sh
ENDSSH

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ SOLUCIÓN COMPLETADA"
    echo "=========================================="
    echo ""
    echo "Ahora puedes:"
    echo "   1. Esperar 20-30 segundos"
    echo "   2. Abrir: http://$EC2_IP:8080"
    echo "   3. Iniciar sesión con: admin / admin"
    echo ""
else
    echo ""
    echo "⚠️  No se pudo ejecutar automáticamente"
    echo ""
    echo "Por favor, ejecuta manualmente:"
    echo "   1. ssh -i $SSH_KEY $EC2_HOST"
    echo "   2. chmod +x ~/fix_airflow.sh"
    echo "   3. ~/fix_airflow.sh"
    echo ""
fi


