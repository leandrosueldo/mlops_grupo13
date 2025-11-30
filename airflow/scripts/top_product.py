"""
Tarea TopProduct: Calcula los 20 productos más vistos por advertiser
"""
import pandas as pd
import boto3
from io import StringIO
import os


def calculate_top_product(s3_bucket, filtered_views_file, output_prefix, date):
    """
    Calcula los 20 productos más vistos por advertiser
    
    Args:
        s3_bucket: Nombre del bucket de S3
        filtered_views_file: Archivo con product_views filtrados
        output_prefix: Prefijo donde guardar los resultados
        date: Fecha del día procesado
    """
    s3_client = boto3.client('s3')
    
    # Leer datos filtrados
    response = s3_client.get_object(Bucket=s3_bucket, Key=filtered_views_file)
    df_views = pd.read_csv(response['Body'])
    
    # Contar vistas por advertiser y producto
    view_counts = df_views.groupby(['advertiser_id', 'product_id']).size().reset_index(name='view_count')
    
    # Obtener top 20 por advertiser
    top_product_results = []
    for advertiser in view_counts['advertiser_id'].unique():
        advertiser_data = view_counts[view_counts['advertiser_id'] == advertiser].copy()
        advertiser_data = advertiser_data.sort_values('view_count', ascending=False).head(20)
        advertiser_data['rank'] = range(1, len(advertiser_data) + 1)
        top_product_results.append(advertiser_data[['advertiser_id', 'product_id', 'view_count', 'rank']])
    
    if top_product_results:
        df_top_product = pd.concat(top_product_results, ignore_index=True)
        df_top_product['model_name'] = 'TopProduct'
        df_top_product['date'] = date
        df_top_product = df_top_product.rename(columns={'view_count': 'score', 'rank': 'rank_position'})
        
        # Guardar resultado
        output_key = f"{output_prefix}/top_product_{date}.csv"
        csv_buffer = StringIO()
        df_top_product.to_csv(csv_buffer, index=False)
        s3_client.put_object(Bucket=s3_bucket, Key=output_key, Body=csv_buffer.getvalue())
        print(f"TopProduct calculado y guardado en {output_key}")
        return output_key
    else:
        print("No se encontraron datos para calcular TopProduct")
        return None


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 5:
        print("Uso: python top_product.py <s3_bucket> <filtered_views_file> <output_prefix> <date>")
        sys.exit(1)
    
    calculate_top_product(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])

