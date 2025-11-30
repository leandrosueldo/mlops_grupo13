#!/bin/bash
# Script para configurar el Security Group de EC2 para permitir acceso a Airflow
# Ejecutar desde tu máquina local

set -e

EC2_IP="18.118.31.28"
REGION="us-east-2"

echo "=========================================="
echo "🔧 CONFIGURANDO SECURITY GROUP"
echo "=========================================="
echo ""

# Verificar que AWS CLI esté instalado
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI no está instalado"
    echo "   Instálalo con: pip install awscli"
    exit 1
fi

# Verificar credenciales de AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ No se pueden verificar las credenciales de AWS"
    echo "   Ejecuta: aws configure"
    exit 1
fi

echo "✅ AWS CLI configurado correctamente"
echo ""

# Obtener Instance ID
echo "📋 Obteniendo información de la instancia EC2..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=ip-address,Values=$EC2_IP" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text \
    --region $REGION 2>/dev/null || echo "")

if [ -z "$INSTANCE_ID" ]; then
    echo "⚠️  No se pudo encontrar la instancia con IP $EC2_IP"
    echo ""
    echo "   Por favor, proporciona el Instance ID manualmente:"
    read -p "   Instance ID: " INSTANCE_ID
    
    if [ -z "$INSTANCE_ID" ]; then
        echo "❌ Instance ID requerido"
        exit 1
    fi
else
    echo "   ✅ Instance ID: $INSTANCE_ID"
fi

# Obtener Security Group ID
SG_ID=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query "Reservations[*].Instances[*].SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "")

if [ -z "$SG_ID" ]; then
    echo "❌ No se pudo obtener el Security Group ID"
    exit 1
fi

echo "   ✅ Security Group ID: $SG_ID"
echo ""

# Verificar reglas existentes
echo "📋 Verificando reglas del Security Group..."
echo ""

# Verificar puerto 22 (SSH)
SSH_RULE=$(aws ec2 describe-security-groups \
    --group-ids $SG_ID \
    --region $REGION \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\`]" \
    --output text 2>/dev/null || echo "")

if [ ! -z "$SSH_RULE" ]; then
    echo "   ✅ Puerto 22 (SSH) ya está abierto"
else
    echo "   ⚠️  Puerto 22 (SSH) no está abierto"
    echo "   🔧 Agregando regla para puerto 22..."
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region $REGION 2>/dev/null && echo "      ✅ Regla agregada" || echo "      ⚠️  Error (puede que ya exista)"
fi

# Verificar puerto 8080 (Airflow)
PORT_8080_EXISTS=$(aws ec2 describe-security-groups \
    --group-ids $SG_ID \
    --region $REGION \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`8080\`]" \
    --output text 2>/dev/null || echo "")

if [ ! -z "$PORT_8080_EXISTS" ]; then
    echo "   ✅ Puerto 8080 (Airflow) ya está abierto"
else
    echo "   ⚠️  Puerto 8080 (Airflow) no está abierto"
    echo "   🔧 Agregando regla para puerto 8080..."
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 8080 \
        --cidr 0.0.0.0/0 \
        --region $REGION 2>/dev/null && echo "      ✅ Regla agregada" || echo "      ⚠️  Error (puede que ya exista)"
fi

echo ""
echo "=========================================="
echo "✅ CONFIGURACIÓN COMPLETADA"
echo "=========================================="
echo ""
echo "📌 Reglas del Security Group:"
aws ec2 describe-security-groups \
    --group-ids $SG_ID \
    --region $REGION \
    --query "SecurityGroups[0].IpPermissions[*].[FromPort,ToPort,IpProtocol,IpRanges[0].CidrIp]" \
    --output table
echo ""
echo "Ahora deberías poder:"
echo "   1. Conectarte por SSH: ssh -i tu-key.pem ec2-user@$EC2_IP"
echo "   2. Acceder a Airflow: http://$EC2_IP:8080"
echo ""


