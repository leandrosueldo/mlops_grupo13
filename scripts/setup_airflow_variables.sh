#!/bin/bash
# Script para configurar variables de Airflow
# Uso: ./setup_airflow_variables.sh <RDS_ENDPOINT>

if [ -z "$1" ]; then
    echo "Uso: $0 <RDS_ENDPOINT>"
    echo "Ejemplo: $0 mlops-postgres-grupo13.xxxxx.us-east-1.rds.amazonaws.com"
    exit 1
fi

RDS_ENDPOINT=$1

echo "Configurando variables de Airflow..."

# Variables de S3
airflow variables set s3_bucket "grupo13-2025"
airflow variables set s3_input_prefix "raw_data"
airflow variables set s3_output_prefix "processed_data"
airflow variables set advertiser_ids_file "raw_data/advertiser_ids"

# Variables de RDS
airflow variables set rds_host "$RDS_ENDPOINT"
airflow variables set rds_port "5432"
airflow variables set rds_database "mlops"
airflow variables set rds_user "postgres"
airflow variables set rds_password "Mimgrupo13"

echo "Variables configuradas exitosamente!"
echo ""
echo "Verificar variables:"
airflow variables list

