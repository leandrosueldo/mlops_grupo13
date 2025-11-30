#!/bin/bash
# Script para ejecutar desde tu terminal local
# Este script intenta conectarse y arreglar Airflow

SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"

echo "=========================================="
echo "🔧 SOLUCIONANDO AIRFLOW"
echo "=========================================="
echo ""

# Verificar clave
if [ ! -f "$SSH_KEY" ]; then
    echo "❌ No se encuentra la clave SSH: $SSH_KEY"
    exit 1
fi

echo "📋 Paso 1: Probando conexión SSH..."
if ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$EC2_HOST" "echo 'OK'" 2>/dev/null; then
    echo "   ✅ Conexión SSH exitosa"
else
    echo "   ⚠️  No se pudo conectar por SSH"
    echo "   Esto puede ser normal - las reglas pueden tardar unos minutos"
    echo "   Continuando de todas formas..."
fi

echo ""
echo "📋 Paso 2: Subiendo script de solución..."
scp -i "$SSH_KEY" -o ConnectTimeout=15 -o StrictHostKeyChecking=no \
    "$(dirname "$0")/fix_airflow_on_ec2.sh" \
    "$EC2_HOST:~/fix_airflow.sh" 2>&1

if [ $? -eq 0 ]; then
    echo "   ✅ Script subido exitosamente"
else
    echo "   ⚠️  Error subiendo script"
    echo "   Intenta manualmente:"
    echo "   scp -i $SSH_KEY scripts/fix_airflow_on_ec2.sh $EC2_HOST:~/fix_airflow.sh"
    exit 1
fi

echo ""
echo "📋 Paso 3: Ejecutando script en EC2..."
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
    echo "   2. Abrir: http://18.118.31.28:8080"
    echo "   3. Iniciar sesión: admin / admin"
    echo ""
else
    echo ""
    echo "⚠️  Hubo un error ejecutando el script"
    echo "   Intenta conectarte manualmente y ejecutar:"
    echo "   ssh -i $SSH_KEY $EC2_HOST"
    echo "   chmod +x ~/fix_airflow.sh"
    echo "   ~/fix_airflow.sh"
    echo ""
fi


