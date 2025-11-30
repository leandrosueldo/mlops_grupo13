#!/bin/bash

# Script para desplegar la API en AWS App Runner
# Requiere: AWS CLI configurado, Docker instalado, y permisos para ECR y App Runner

set -e

echo "🚀 Iniciando despliegue de API en AWS App Runner..."

# Configuración
REGION="us-east-2"
ECR_REPO_NAME="grupo13-recommendations-api"
APP_RUNNER_SERVICE_NAME="grupo13-recommendations-api"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📦 Paso 1: Creando repositorio ECR..."
aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $REGION 2>/dev/null || \
    aws ecr create-repository --repository-name $ECR_REPO_NAME --region $REGION --image-scanning-configuration scanOnPush=true

ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}:latest"

echo "🐳 Paso 2: Construyendo imagen Docker..."
cd "$(dirname "$0")/../api"
docker build -t $ECR_REPO_NAME:latest .

echo "🔐 Paso 3: Autenticando Docker con ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URI

echo "📤 Paso 4: Etiquetando y subiendo imagen a ECR..."
docker tag $ECR_REPO_NAME:latest $ECR_URI
docker push $ECR_URI

echo "✅ Imagen subida a ECR: $ECR_URI"

echo ""
echo "📝 Paso 5: Creando servicio en App Runner..."
echo "⚠️  Nota: Debes crear el servicio manualmente desde la consola de AWS o usar el archivo apprunner-config.json"
echo ""
echo "Para crear el servicio, ejecuta:"
echo "  aws apprunner create-service --cli-input-json file://apprunner-config.json --region $REGION"
echo ""
echo "O crea el servicio desde la consola de AWS App Runner usando la URI: $ECR_URI"



