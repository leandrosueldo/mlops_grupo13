#!/bin/bash

# Script para crear el rol IAM para App Runner

set -e

echo "🔐 Creando rol IAM para App Runner..."

ROLE_NAME="apprunner-service-role"
POLICY_ARN="arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"

# Crear el rol con la política de confianza para App Runner
cat > /tmp/apprunner-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "build.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Verificar si el rol ya existe
if aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
    echo "⚠️  El rol $ROLE_NAME ya existe"
    read -p "¿Deseas continuar de todas formas? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
else
    echo "📝 Creando rol $ROLE_NAME..."
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file:///tmp/apprunner-trust-policy.json \
        --description "Rol para App Runner para acceder a ECR"
    
    echo "✅ Rol creado"
fi

# Adjuntar la política para acceso a ECR
echo "📎 Adjuntando política para acceso a ECR..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn $POLICY_ARN

echo "✅ Política adjuntada"
echo ""
echo "✅ Rol IAM creado exitosamente: $ROLE_NAME"
echo "   ARN: arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/$ROLE_NAME"

# Limpiar archivo temporal
rm -f /tmp/apprunner-trust-policy.json



