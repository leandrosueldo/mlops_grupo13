#!/bin/bash
# Script para configurar App Runner

set -e

echo "=========================================="
echo "CONFIGURANDO APP RUNNER"
echo "=========================================="

SSH_KEY="$HOME/Downloads/airflow-grupo13-key.pem"
EC2_HOST="ec2-user@18.118.31.28"
ECR_REPO="396913735447.dkr.ecr.us-east-2.amazonaws.com/grupo13-recommendations-api"
REGION="us-east-2"

# 1. Verificar/Crear repositorio ECR
echo ""
echo "1. Verificando repositorio ECR..."
if aws ecr describe-repositories --repository-names grupo13-recommendations-api --region $REGION 2>/dev/null | grep -q "repositoryName"; then
    echo "   ✅ Repositorio ECR existe"
else
    echo "   Creando repositorio ECR..."
    aws ecr create-repository --repository-name grupo13-recommendations-api --region $REGION
    echo "   ✅ Repositorio creado"
fi

# 2. Construir imagen Docker en EC2
echo ""
echo "2. Construyendo imagen Docker en EC2..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" << 'ENDSSH'
cd ~/MaterialTP/api || cd ~/api || (echo "⚠️  Directorio api no encontrado" && exit 1)

# Asegurarse de que Docker esté corriendo
sudo systemctl start docker 2>/dev/null || true
sleep 2

# Login a ECR
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 396913735447.dkr.ecr.us-east-2.amazonaws.com

# Construir imagen
echo "   Construyendo imagen..."
docker build -t grupo13-recommendations-api:latest .

# Tag para ECR
docker tag grupo13-recommendations-api:latest 396913735447.dkr.ecr.us-east-2.amazonaws.com/grupo13-recommendations-api:latest

# Push a ECR
echo "   Subiendo imagen a ECR..."
docker push 396913735447.dkr.ecr.us-east-2.amazonaws.com/grupo13-recommendations-api:latest

echo "   ✅ Imagen subida exitosamente"
ENDSSH

# 3. Verificar/Crear rol IAM para App Runner
echo ""
echo "3. Verificando rol IAM para App Runner..."
if aws iam get-role --role-name apprunner-service-role --region $REGION 2>/dev/null | grep -q "RoleName"; then
    echo "   ✅ Rol IAM existe"
else
    echo "   Creando rol IAM..."
    cat > /tmp/apprunner-trust-policy.json << 'EOF'
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
    
    aws iam create-role \
        --role-name apprunner-service-role \
        --assume-role-policy-document file:///tmp/apprunner-trust-policy.json \
        --description "Service role for AWS App Runner to access ECR"
    
    aws iam attach-role-policy \
        --role-name apprunner-service-role \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess
    
    echo "   ✅ Rol IAM creado"
    rm /tmp/apprunner-trust-policy.json
fi

# 4. Crear servicio App Runner
echo ""
echo "4. Creando servicio App Runner..."
if aws apprunner list-services --region $REGION 2>/dev/null | grep -q "grupo13-recommendations-api"; then
    echo "   ✅ Servicio App Runner ya existe"
    SERVICE_ARN=$(aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='grupo13-recommendations-api'].ServiceArn" --output text)
    echo "   ARN: $SERVICE_ARN"
else
    if [ -f "apprunner-config.json" ]; then
        echo "   Creando servicio desde apprunner-config.json..."
        aws apprunner create-service --cli-input-json file://apprunner-config.json --region $REGION
        echo "   ✅ Servicio creado"
    else
        echo "   ⚠️  apprunner-config.json no encontrado"
        echo "   Creando servicio manualmente..."
        
        cat > /tmp/apprunner-config.json << EOF
{
  "ServiceName": "grupo13-recommendations-api",
  "SourceConfiguration": {
    "ImageRepository": {
      "ImageIdentifier": "$ECR_REPO:latest",
      "ImageConfiguration": {
        "Port": "8000",
        "RuntimeEnvironmentVariables": {
          "RDS_HOST": "mimgrupo13.cpomi0gaon83.us-east-2.rds.amazonaws.com",
          "RDS_PORT": "5432",
          "RDS_DATABASE": "mlops",
          "RDS_USER": "postgres",
          "RDS_PASSWORD": "Mimgrupo13"
        }
      },
      "ImageRepositoryType": "ECR"
    },
    "AutoDeploymentsEnabled": false,
    "AuthenticationConfiguration": {
      "AccessRoleArn": "arn:aws:iam::396913735447:role/apprunner-service-role"
    }
  },
  "InstanceConfiguration": {
    "Cpu": "256",
    "Memory": "512",
    "InstanceRoleArn": "arn:aws:iam::396913735447:role/apprunner-service-role"
  },
  "HealthCheckConfiguration": {
    "Protocol": "HTTP",
    "Path": "/health",
    "Interval": 10,
    "Timeout": 5,
    "HealthyThreshold": 1,
    "UnhealthyThreshold": 5
  }
}
EOF
        
        aws apprunner create-service --cli-input-json file:///tmp/apprunner-config.json --region $REGION
        rm /tmp/apprunner-config.json
        echo "   ✅ Servicio creado"
    fi
fi

# 5. Verificar estado del servicio
echo ""
echo "5. Verificando estado del servicio..."
sleep 5
SERVICE_ARN=$(aws apprunner list-services --region $REGION --query "ServiceSummaryList[?ServiceName=='grupo13-recommendations-api'].ServiceArn" --output text 2>/dev/null)
if [ -n "$SERVICE_ARN" ]; then
    STATUS=$(aws apprunner describe-service --service-arn "$SERVICE_ARN" --region $REGION --query "Service.Status" --output text 2>/dev/null)
    SERVICE_URL=$(aws apprunner describe-service --service-arn "$SERVICE_ARN" --region $REGION --query "Service.ServiceUrl" --output text 2>/dev/null)
    echo "   Estado: $STATUS"
    echo "   URL: $SERVICE_URL"
    
    if [ "$STATUS" = "RUNNING" ]; then
        echo "   ✅ Servicio App Runner está corriendo"
    else
        echo "   ⏳ Servicio en estado: $STATUS (puede tardar unos minutos)"
    fi
else
    echo "   ⚠️  No se pudo obtener información del servicio"
fi

echo ""
echo "=========================================="
echo "CONFIGURACIÓN COMPLETA"
echo "=========================================="
echo "App Runner puede tardar 5-10 minutos en estar disponible"
echo "Verifica el estado en: AWS Console > App Runner"



