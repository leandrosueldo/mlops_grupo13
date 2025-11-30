"""
API FastAPI para servir recomendaciones de productos
"""
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime, timedelta
import os
from typing import List, Dict, Optional

app = FastAPI(title="Recommendations API", version="1.0.0")

# Configuración de base de datos desde variables de entorno
DB_CONFIG = {
    'host': os.getenv('RDS_HOST', 'localhost'),
    'port': os.getenv('RDS_PORT', '5432'),
    'database': os.getenv('RDS_DATABASE', 'mlops'),
    'user': os.getenv('RDS_USER', 'postgres'),
    'password': os.getenv('RDS_PASSWORD', 'password'),
}


def get_db_connection():
    """Crea una conexión a la base de datos PostgreSQL"""
    try:
        conn = psycopg2.connect(
            host=DB_CONFIG['host'],
            port=DB_CONFIG['port'],
            database=DB_CONFIG['database'],
            user=DB_CONFIG['user'],
            password=DB_CONFIG['password']
        )
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error conectando a la base de datos: {str(e)}")


@app.get("/")
def root():
    """Endpoint raíz"""
    return {"message": "Recommendations API", "version": "1.0.0"}


@app.get("/recommendations/{advertiser_id}/{model_name}")
def get_recommendations(advertiser_id: str, model_name: str):
    """
    Devuelve las recomendaciones del día para un advertiser y modelo específico
    
    Args:
        advertiser_id: ID del advertiser
        model_name: Nombre del modelo ('TopCTR' o 'TopProduct')
    
    Returns:
        JSON con las recomendaciones ordenadas por rank_position
    """
    if model_name not in ['TopCTR', 'TopProduct']:
        raise HTTPException(status_code=400, detail="Modelo debe ser 'TopCTR' o 'TopProduct'")
    
    today = datetime.now().date()
    yesterday = today - timedelta(days=1)
    
    conn = get_db_connection()
    try:
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        # Buscar la fecha más reciente disponible para este advertiser y modelo
        cursor.execute("""
            SELECT MAX(date) as max_date
            FROM recommendations
            WHERE advertiser_id = %s AND model_name = %s
        """, (advertiser_id, model_name))
        max_date_result = cursor.fetchone()
        
        if not max_date_result or not max_date_result['max_date']:
            raise HTTPException(
                status_code=404, 
                detail=f"No se encontraron recomendaciones para advertiser {advertiser_id} y modelo {model_name}"
            )
        
        result_date = max_date_result['max_date']
        
        # Buscar recomendaciones para esa fecha
        query = """
            SELECT product_id, rank_position, score, date
            FROM recommendations
            WHERE advertiser_id = %s 
                AND model_name = %s 
                AND date = %s
            ORDER BY rank_position ASC
            LIMIT 20
        """
        cursor.execute(query, (advertiser_id, model_name, result_date))
        results = cursor.fetchall()
        
        if not results:
            raise HTTPException(
                status_code=404, 
                detail=f"No se encontraron recomendaciones para advertiser {advertiser_id} y modelo {model_name}"
            )
        
        return {
            "advertiser_id": advertiser_id,
            "model_name": model_name,
            "date": str(result_date),
            "recommendations": [dict(row) for row in results]
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo recomendaciones: {str(e)}")
    finally:
        cursor.close()
        conn.close()


@app.get("/stats/")
def get_stats():
    """
    Devuelve estadísticas sobre las recomendaciones
    
    Returns:
        JSON con estadísticas agregadas
    """
    today = datetime.now().date()
    yesterday = today - timedelta(days=1)
    
    conn = get_db_connection()
    try:
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        # Obtener la fecha más reciente disponible en toda la tabla
        cursor.execute("""
            SELECT MAX(date) as max_date
            FROM recommendations
        """)
        max_date_result = cursor.fetchone()
        if not max_date_result or not max_date_result['max_date']:
            return {
                "date": str(today),
                "total_advertisers": 0,
                "advertisers_with_both_models": 0,
                "model_coincidence": [],
                "top_variation_advertisers": []
            }
        max_date = max_date_result['max_date']
        
        # Cantidad de advertisers únicos
        cursor.execute("""
            SELECT COUNT(DISTINCT advertiser_id) as total_advertisers
            FROM recommendations
            WHERE date = %s
        """, (max_date,))
        total_advertisers = cursor.fetchone()['total_advertisers']
        
        # Advertisers con recomendaciones en ambos modelos
        cursor.execute("""
            SELECT advertiser_id, COUNT(DISTINCT model_name) as model_count
            FROM recommendations
            WHERE date = %s
            GROUP BY advertiser_id
            HAVING COUNT(DISTINCT model_name) = 2
        """, (max_date,))
        advertisers_both_models = len(cursor.fetchall())
        
        # Coincidencia entre modelos (productos que aparecen en ambos modelos para el mismo advertiser)
        cursor.execute("""
            SELECT 
                r1.advertiser_id,
                COUNT(DISTINCT r1.product_id) as common_products
            FROM recommendations r1
            INNER JOIN recommendations r2 
                ON r1.advertiser_id = r2.advertiser_id 
                AND r1.product_id = r2.product_id
                AND r1.date = r2.date
            WHERE r1.model_name = 'TopCTR' 
                AND r2.model_name = 'TopProduct'
                AND r1.date = %s
            GROUP BY r1.advertiser_id
        """, (max_date,))
        model_coincidence = cursor.fetchall()
        
        # Estadísticas de variación (comparar con el día anterior)
        prev_date = max_date - timedelta(days=1)
        cursor.execute("""
            SELECT 
                r1.advertiser_id,
                COUNT(DISTINCT CASE WHEN r2.product_id IS NULL THEN r1.product_id END) as new_products,
                COUNT(DISTINCT CASE WHEN r2.product_id IS NOT NULL THEN r1.product_id END) as same_products
            FROM recommendations r1
            LEFT JOIN recommendations r2 
                ON r1.advertiser_id = r2.advertiser_id 
                AND r1.product_id = r2.product_id
                AND r1.model_name = r2.model_name
                AND r2.date = %s
            WHERE r1.date = %s
            GROUP BY r1.advertiser_id
        """, (prev_date, max_date))
        variation_stats = cursor.fetchall()
        
        # Advertisers con más variación
        advertisers_variation = sorted(
            variation_stats,
            key=lambda x: x['new_products'] / (x['new_products'] + x['same_products']) if (x['new_products'] + x['same_products']) > 0 else 0,
            reverse=True
        )[:5]
        
        return {
            "date": str(max_date),
            "total_advertisers": total_advertisers,
            "advertisers_with_both_models": advertisers_both_models,
            "model_coincidence": [dict(row) for row in model_coincidence],
            "top_variation_advertisers": [
                {
                    "advertiser_id": row['advertiser_id'],
                    "variation_rate": row['new_products'] / (row['new_products'] + row['same_products']) if (row['new_products'] + row['same_products']) > 0 else 0,
                    "new_products": row['new_products'],
                    "same_products": row['same_products']
                }
                for row in advertisers_variation
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo estadísticas: {str(e)}")
    finally:
        cursor.close()
        conn.close()


@app.get("/history/{advertiser_id}/")
def get_history(advertiser_id: str):
    """
    Devuelve todas las recomendaciones para un advertiser en los últimos 7 días
    
    Args:
        advertiser_id: ID del advertiser
    
    Returns:
        JSON con recomendaciones históricas agrupadas por fecha y modelo
    """
    today = datetime.now().date()
    seven_days_ago = today - timedelta(days=7)
    
    conn = get_db_connection()
    try:
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        query = """
            SELECT model_name, product_id, rank_position, score, date
            FROM recommendations
            WHERE advertiser_id = %s 
                AND date >= %s
                AND date <= %s
            ORDER BY date DESC, model_name, rank_position ASC
        """
        cursor.execute(query, (advertiser_id, seven_days_ago, today))
        results = cursor.fetchall()
        
        if not results:
            raise HTTPException(
                status_code=404,
                detail=f"No se encontraron recomendaciones para advertiser {advertiser_id} en los últimos 7 días"
            )
        
        # Agrupar por fecha y modelo
        history = {}
        for row in results:
            date_str = str(row['date'])
            model = row['model_name']
            
            if date_str not in history:
                history[date_str] = {}
            if model not in history[date_str]:
                history[date_str][model] = []
            
            history[date_str][model].append({
                "product_id": row['product_id'],
                "rank_position": row['rank_position'],
                "score": float(row['score'])
            })
        
        return {
            "advertiser_id": advertiser_id,
            "period": {
                "start_date": str(seven_days_ago),
                "end_date": str(today)
            },
            "history": history
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error obteniendo historial: {str(e)}")
    finally:
        cursor.close()
        conn.close()


@app.get("/health")
def health_check():
    """
    Endpoint de health check - debe devolver 200 OK para App Runner
    Simplificado para que siempre devuelva 200 OK sin verificar DB
    """
    return {"status": "ok"}

