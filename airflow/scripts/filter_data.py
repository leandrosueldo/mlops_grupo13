"""
Tarea FiltrarDatos: Filtra los logs para mantener solo advertisers activos
"""
import pandas as pd
import boto3
from io import StringIO
import os


def filter_data(s3_bucket, input_prefix, output_prefix, advertiser_ids_file, date):
    """
    Filtra los logs del día para mantener solo advertisers activos
    
    Args:
        s3_bucket: Nombre del bucket de S3
        input_prefix: Prefijo donde están los datos crudos
        output_prefix: Prefijo donde guardar los datos filtrados
        advertiser_ids_file: Archivo con la lista de advertisers activos
        date: Fecha del día a procesar (formato YYYY-MM-DD)
    """
    s3_client = boto3.client('s3')
    
    # Leer lista de advertisers activos
    response = s3_client.get_object(Bucket=s3_bucket, Key=advertiser_ids_file)
    active_advertisers_df = pd.read_csv(response['Body'])
    active_advertisers = set(active_advertisers_df['advertiser_id'].tolist())
    
    # Procesar product_views
    product_views_key = f"{input_prefix}/product_views"
    try:
        response = s3_client.get_object(Bucket=s3_bucket, Key=product_views_key)
        df_product_views = pd.read_csv(response['Body'])
        
        # Filtrar por fecha y advertisers activos
        df_product_views['date'] = pd.to_datetime(df_product_views['date'])
        df_filtered_views = df_product_views[
            (df_product_views['date'].dt.date == pd.to_datetime(date).date()) &
            (df_product_views['advertiser_id'].isin(active_advertisers))
        ]
        
        # Guardar resultado filtrado
        output_key = f"{output_prefix}/product_views_filtered_{date}.csv"
        csv_buffer = StringIO()
        df_filtered_views.to_csv(csv_buffer, index=False)
        s3_client.put_object(Bucket=s3_bucket, Key=output_key, Body=csv_buffer.getvalue())
        print(f"Product views filtrados guardados en {output_key}: {len(df_filtered_views)} registros")
    except Exception as e:
        print(f"Error procesando product_views: {e}")
        raise
    
    # Procesar ads_views
    ads_views_key = f"{input_prefix}/ads_views"
    try:
        response = s3_client.get_object(Bucket=s3_bucket, Key=ads_views_key)
        df_ads_views = pd.read_csv(response['Body'])
        
        # Filtrar por fecha y advertisers activos
        df_ads_views['date'] = pd.to_datetime(df_ads_views['date'])
        df_filtered_ads = df_ads_views[
            (df_ads_views['date'].dt.date == pd.to_datetime(date).date()) &
            (df_ads_views['advertiser_id'].isin(active_advertisers))
        ]
        
        # Guardar resultado filtrado
        output_key = f"{output_prefix}/ads_views_filtered_{date}.csv"
        csv_buffer = StringIO()
        df_filtered_ads.to_csv(csv_buffer, index=False)
        s3_client.put_object(Bucket=s3_bucket, Key=output_key, Body=csv_buffer.getvalue())
        print(f"Ads views filtrados guardados en {output_key}: {len(df_filtered_ads)} registros")
    except Exception as e:
        print(f"Error procesando ads_views: {e}")
        raise
    
    return {
        'product_views_filtered': f"{output_prefix}/product_views_filtered_{date}.csv",
        'ads_views_filtered': f"{output_prefix}/ads_views_filtered_{date}.csv"
    }


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 6:
        print("Uso: python filter_data.py <s3_bucket> <input_prefix> <output_prefix> <advertiser_ids_file> <date>")
        sys.exit(1)
    
    filter_data(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])

