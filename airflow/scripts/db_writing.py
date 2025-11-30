"""
Tarea DBWriting: Escribe los resultados de los modelos en PostgreSQL
"""
import pandas as pd
import boto3
import psycopg2
from io import StringIO
import os


def write_to_db(s3_bucket, top_ctr_file, top_product_file, db_config, date):
    """
    Escribe los resultados de ambos modelos en la base de datos PostgreSQL
    
    Args:
        s3_bucket: Nombre del bucket de S3
        top_ctr_file: Archivo con resultados de TopCTR
        top_product_file: Archivo con resultados de TopProduct
        db_config: Diccionario con configuración de la base de datos
                   {'host': ..., 'port': ..., 'database': ..., 'user': ..., 'password': ...}
        date: Fecha del día procesado
    """
    s3_client = boto3.client('s3')
    
    # Conectar a la base de datos
    # Agregar sslmode='require' para conexiones a RDS
    conn = psycopg2.connect(
        host=db_config['host'],
        port=db_config['port'],
        database=db_config['database'],
        user=db_config['user'],
        password=db_config['password'],
        sslmode='require'
    )
    cursor = conn.cursor()
    
    try:
        # Leer y escribir TopCTR
        if top_ctr_file:
            response = s3_client.get_object(Bucket=s3_bucket, Key=top_ctr_file)
            df_top_ctr = pd.read_csv(response['Body'])
            
            # Eliminar registros del día si existen (para evitar duplicados)
            delete_query = """
                DELETE FROM recommendations 
                WHERE date = %s AND model_name = 'TopCTR'
            """
            cursor.execute(delete_query, (date,))
            
            # Insertar nuevos registros
            insert_query = """
                INSERT INTO recommendations 
                (advertiser_id, model_name, product_id, rank_position, score, date)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (advertiser_id, model_name, product_id, date) 
                DO UPDATE SET rank_position = EXCLUDED.rank_position, score = EXCLUDED.score
            """
            
            for _, row in df_top_ctr.iterrows():
                cursor.execute(insert_query, (
                    row['advertiser_id'],
                    row['model_name'],
                    row['product_id'],
                    int(row['rank_position']),
                    float(row['score']),
                    row['date']
                ))
            
            print(f"TopCTR: {len(df_top_ctr)} registros escritos en la base de datos")
        
        # Leer y escribir TopProduct
        if top_product_file:
            response = s3_client.get_object(Bucket=s3_bucket, Key=top_product_file)
            df_top_product = pd.read_csv(response['Body'])
            
            # Eliminar registros del día si existen
            delete_query = """
                DELETE FROM recommendations 
                WHERE date = %s AND model_name = 'TopProduct'
            """
            cursor.execute(delete_query, (date,))
            
            # Insertar nuevos registros
            insert_query = """
                INSERT INTO recommendations 
                (advertiser_id, model_name, product_id, rank_position, score, date)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (advertiser_id, model_name, product_id, date) 
                DO UPDATE SET rank_position = EXCLUDED.rank_position, score = EXCLUDED.score
            """
            
            for _, row in df_top_product.iterrows():
                cursor.execute(insert_query, (
                    row['advertiser_id'],
                    row['model_name'],
                    row['product_id'],
                    int(row['rank_position']),
                    float(row['score']),
                    row['date']
                ))
            
            print(f"TopProduct: {len(df_top_product)} registros escritos en la base de datos")
        
        # Confirmar transacción
        conn.commit()
        print("Datos escritos exitosamente en la base de datos")
        
    except Exception as e:
        conn.rollback()
        print(f"Error escribiendo en la base de datos: {e}")
        raise
    finally:
        cursor.close()
        conn.close()


if __name__ == "__main__":
    import sys
    import json
    
    if len(sys.argv) != 5:
        print("Uso: python db_writing.py <s3_bucket> <top_ctr_file> <top_product_file> <db_config_json>")
        sys.exit(1)
    
    db_config = json.loads(sys.argv[4])
    date = sys.argv[5] if len(sys.argv) > 5 else None
    
    write_to_db(sys.argv[1], sys.argv[2], sys.argv[3], db_config, date)

