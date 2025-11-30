#!/bin/bash
# Script para verificar archivos en S3

BUCKET_NAME=${1:-"grupo13-2025"}
PREFIX="raw_data"

echo "Verificando archivos en S3 bucket: $BUCKET_NAME"
echo ""

# Verificar si el bucket existe
if ! aws s3 ls "s3://$BUCKET_NAME" &> /dev/null; then
    echo "✗ Error: El bucket '$BUCKET_NAME' no existe o no tienes acceso"
    exit 1
fi

echo "✓ Bucket existe"
echo ""

# Listar archivos
echo "Archivos en s3://$BUCKET_NAME/$PREFIX/:"
aws s3 ls "s3://$BUCKET_NAME/$PREFIX/" || echo "  (directorio vacío o no existe)"

echo ""
echo "Verificando archivos requeridos:"

# Verificar advertiser_ids
if aws s3 ls "s3://$BUCKET_NAME/$PREFIX/advertiser_ids" &> /dev/null; then
    SIZE=$(aws s3 ls "s3://$BUCKET_NAME/$PREFIX/advertiser_ids" | awk '{print $3}')
    echo "✓ advertiser_ids existe ($SIZE bytes)"
else
    echo "✗ advertiser_ids NO existe"
fi

# Verificar product_views
if aws s3 ls "s3://$BUCKET_NAME/$PREFIX/product_views" &> /dev/null; then
    SIZE=$(aws s3 ls "s3://$BUCKET_NAME/$PREFIX/product_views" | awk '{print $3}')
    echo "✓ product_views existe ($SIZE bytes)"
else
    echo "✗ product_views NO existe"
fi

# Verificar ads_views
if aws s3 ls "s3://$BUCKET_NAME/$PREFIX/ads_views" &> /dev/null; then
    SIZE=$(aws s3 ls "s3://$BUCKET_NAME/$PREFIX/ads_views" | awk '{print $3}')
    echo "✓ ads_views existe ($SIZE bytes)"
else
    echo "✗ ads_views NO existe"
fi

