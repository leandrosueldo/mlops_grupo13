#!/bin/bash

# Script completo para construir y desplegar la API en App Runner desde EC2

set -e

echo "🚀 Iniciando construcción y despliegue de la API..."

# Configuración
EC2_HOST="18.118.31.28"
EC2_USER="ec2-user"
KEY_PATH="$HOME/Downloads/airflow-grupo13-key.pem"
REGION="us-east-2"
ECR_REPO_NAME="grupo13-recommendations-api"
AWS_ACCOUNT_ID="396913735447"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO_NAME}:latest"

echo "📦 Paso 1: Instalando Docker en EC2..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << 'ENDSSH'
    # Instalar Docker si no está instalado
    if ! command -v docker &> /dev/null; then
        echo "Instalando Docker..."
        sudo yum update -y
        sudo yum install -y docker
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker ec2-user
        echo "✅ Docker instalado"
    else
        echo "✅ Docker ya está instalado"
        docker --version
    fi
    
    # Verificar que Docker esté corriendo
    sudo systemctl status docker --no-pager || sudo systemctl start docker
ENDSSH

echo "📤 Paso 2: Subiendo archivos de la API a EC2..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no -r api/ ${EC2_USER}@${EC2_HOST}:~/api/

echo "🐳 Paso 3: Construyendo imagen Docker en EC2..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << ENDSSH
    cd ~/api
    sudo docker build -t ${ECR_REPO_NAME}:latest .
    echo "✅ Imagen construida"
ENDSSH

echo "🔐 Paso 4: Autenticando Docker con ECR..."
aws ecr get-login-password --region ${REGION} | ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} "sudo docker login --username AWS --password-stdin ${ECR_URI}"

echo "📤 Paso 5: Etiquetando y subiendo imagen a ECR..."
ssh -i "$KEY_PATH" -o StrictHostKeyChecking=no ${EC2_USER}@${EC2_HOST} << ENDSSH
    sudo docker tag ${ECR_REPO_NAME}:latest ${ECR_URI}
    sudo docker push ${ECR_URI}
    echo "✅ Imagen subida a ECR"
ENDSSH

echo ""
echo "✅ Imagen Docker construida y subida exitosamente!"
echo "   URI: ${ECR_URI}"
echo ""
echo "📝 Paso 6: Creando servicio en App Runner..."



