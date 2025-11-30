#!/bin/bash
# Script para subir datos a S3

BUCKET_NAME=${1:-"mlops-tp-bucket"}
INPUT_PREFIX="raw_data"

echo "Subiendo datos a S3 bucket: $BUCKET_NAME"

# Verificar que los archivos existan
if [ ! -f "advertiser_ids" ]; then
    echo "Error: No se encuentra el archivo advertiser_ids"
    echo "Ejecuta primero el notebook GenerateTPData.ipynb"
    exit 1
fi

if [ ! -f "product_views" ]; then
    echo "Error: No se encuentra el archivo product_views"
    exit 1
fi

if [ ! -f "ads_views" ]; then
    echo "Error: No se encuentra el archivo ads_views"
    exit 1
fi

# Subir archivos
echo "Subiendo advertiser_ids..."
aws s3 cp advertiser_ids s3://$BUCKET_NAME/$INPUT_PREFIX/advertiser_ids

echo "Subiendo product_views..."
aws s3 cp product_views s3://$BUCKET_NAME/$INPUT_PREFIX/product_views

echo "Subiendo ads_views..."
aws s3 cp ads_views s3://$BUCKET_NAME/$INPUT_PREFIX/ads_views

echo "¡Datos subidos exitosamente!"

