"""
Tarea TopCTR: Calcula los 20 productos con mejor CTR por advertiser
"""
import pandas as pd
import boto3
from io import StringIO
import os


def calculate_top_ctr(s3_bucket, filtered_ads_file, output_prefix, date):
    """
    Calcula los 20 productos con mejor CTR por advertiser
    
    Args:
        s3_bucket: Nombre del bucket de S3
        filtered_ads_file: Archivo con ads_views filtrados
        output_prefix: Prefijo donde guardar los resultados
        date: Fecha del día procesado
    """
    s3_client = boto3.client('s3')
    
    # Leer datos filtrados
    response = s3_client.get_object(Bucket=s3_bucket, Key=filtered_ads_file)
    df_ads = pd.read_csv(response['Body'])
    
    # Calcular CTR por advertiser y producto
    # CTR = clicks / impressions
    df_ads['is_click'] = (df_ads['type'] == 'click').astype(int)
    df_ads['is_impression'] = (df_ads['type'] == 'impression').astype(int)
    
    # Agrupar por advertiser_id y product_id
    ctr_data = df_ads.groupby(['advertiser_id', 'product_id']).agg({
        'is_click': 'sum',
        'is_impression': 'sum'
    }).reset_index()
    
    # Calcular CTR
    ctr_data['ctr'] = ctr_data['is_click'] / ctr_data['is_impression'].replace(0, 1)
    
    # Obtener top 20 por advertiser
    top_ctr_results = []
    for advertiser in ctr_data['advertiser_id'].unique():
        advertiser_data = ctr_data[ctr_data['advertiser_id'] == advertiser].copy()
        advertiser_data = advertiser_data.sort_values('ctr', ascending=False).head(20)
        advertiser_data['rank'] = range(1, len(advertiser_data) + 1)
        top_ctr_results.append(advertiser_data[['advertiser_id', 'product_id', 'ctr', 'rank']])
    
    if top_ctr_results:
        df_top_ctr = pd.concat(top_ctr_results, ignore_index=True)
        df_top_ctr['model_name'] = 'TopCTR'
        df_top_ctr['date'] = date
        df_top_ctr = df_top_ctr.rename(columns={'ctr': 'score', 'rank': 'rank_position'})
        
        # Guardar resultado
        output_key = f"{output_prefix}/top_ctr_{date}.csv"
        csv_buffer = StringIO()
        df_top_ctr.to_csv(csv_buffer, index=False)
        s3_client.put_object(Bucket=s3_bucket, Key=output_key, Body=csv_buffer.getvalue())
        print(f"TopCTR calculado y guardado en {output_key}")
        return output_key
    else:
        print("No se encontraron datos para calcular TopCTR")
        return None


if __name__ == "__main__":
    import sys
    if len(sys.argv) != 5:
        print("Uso: python top_ctr.py <s3_bucket> <filtered_ads_file> <output_prefix> <date>")
        sys.exit(1)
    
    calculate_top_ctr(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])

