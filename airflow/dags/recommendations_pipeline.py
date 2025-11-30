"""
DAG de Airflow para el pipeline de recomendaciones
Ejecuta diariamente: FiltrarDatos -> TopCTR, TopProduct -> DBWriting
"""
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from airflow.models import Variable
from datetime import datetime, timedelta
import sys
import os

# Agregar el directorio de scripts al path (solo una vez)
_scripts_path = os.path.join(os.path.dirname(__file__), '..', 'scripts')
if _scripts_path not in sys.path:
    sys.path.insert(0, _scripts_path)

# Configuración por defecto
default_args = {
    'owner': 'mlops',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Crear el DAG
dag = DAG(
    'recommendations_pipeline',
    default_args=default_args,
    description='Pipeline diario para generar recomendaciones de productos',
    schedule_interval='0 2 * * *',  # Ejecutar todos los días a las 2 AM
    start_date=days_ago(1),
    catchup=False,
    tags=['mlops', 'recommendations'],
)


def get_execution_date(**context):
    """Obtiene la fecha de ejecución del DAG"""
    execution_date = context['execution_date']
    return execution_date.strftime('%Y-%m-%d')


# Tarea 1: FiltrarDatos
def task_filter_data_wrapper(**context):
    """Wrapper para la tarea de filtrar datos"""
    # Importar aquí para evitar timeout en la carga del DAG
    from filter_data import filter_data
    
    execution_date = context['execution_date'].strftime('%Y-%m-%d')
    
    # Obtener variables de Airflow
    s3_bucket = Variable.get("s3_bucket", default_var="grupo13-2025")
    s3_input_prefix = Variable.get("s3_input_prefix", default_var="raw_data")
    s3_output_prefix = Variable.get("s3_output_prefix", default_var="processed_data")
    advertiser_ids_file = Variable.get("advertiser_ids_file", default_var="advertiser_ids")
    
    return filter_data(
        s3_bucket,
        s3_input_prefix,
        s3_output_prefix,
        advertiser_ids_file,
        execution_date
    )


task_filter_data = PythonOperator(
    task_id='filter_data',
    python_callable=task_filter_data_wrapper,
    dag=dag,
)


# Tarea 2: TopCTR
def task_top_ctr_wrapper(**context):
    """Wrapper para calcular TopCTR"""
    # Importar aquí para evitar timeout en la carga del DAG
    from top_ctr import calculate_top_ctr
    
    execution_date = context['execution_date'].strftime('%Y-%m-%d')
    
    s3_bucket = Variable.get("s3_bucket", default_var="grupo13-2025")
    s3_output_prefix = Variable.get("s3_output_prefix", default_var="processed_data")
    filtered_ads_file = f"{s3_output_prefix}/ads_views_filtered_{execution_date}.csv"
    
    return calculate_top_ctr(
        s3_bucket,
        filtered_ads_file,
        s3_output_prefix,
        execution_date
    )


task_top_ctr = PythonOperator(
    task_id='top_ctr',
    python_callable=task_top_ctr_wrapper,
    dag=dag,
)


# Tarea 3: TopProduct
def task_top_product_wrapper(**context):
    """Wrapper para calcular TopProduct"""
    # Importar aquí para evitar timeout en la carga del DAG
    from top_product import calculate_top_product
    
    execution_date = context['execution_date'].strftime('%Y-%m-%d')
    
    s3_bucket = Variable.get("s3_bucket", default_var="grupo13-2025")
    s3_output_prefix = Variable.get("s3_output_prefix", default_var="processed_data")
    filtered_views_file = f"{s3_output_prefix}/product_views_filtered_{execution_date}.csv"
    
    return calculate_top_product(
        s3_bucket,
        filtered_views_file,
        s3_output_prefix,
        execution_date
    )


task_top_product = PythonOperator(
    task_id='top_product',
    python_callable=task_top_product_wrapper,
    dag=dag,
)


# Tarea 4: DBWriting
def task_db_writing_wrapper(**context):
    """Wrapper para escribir en la base de datos"""
    # Importar aquí para evitar timeout en la carga del DAG
    from db_writing import write_to_db
    
    execution_date = context['execution_date'].strftime('%Y-%m-%d')
    
    s3_bucket = Variable.get("s3_bucket", default_var="grupo13-2025")
    s3_output_prefix = Variable.get("s3_output_prefix", default_var="processed_data")
    top_ctr_file = f"{s3_output_prefix}/top_ctr_{execution_date}.csv"
    top_product_file = f"{s3_output_prefix}/top_product_{execution_date}.csv"
    
    # Obtener configuración de DB desde variables de Airflow
    db_config = {
        'host': Variable.get("rds_host", default_var="localhost"),
        'port': int(Variable.get("rds_port", default_var="5432")),
        'database': Variable.get("rds_database", default_var="mlops"),
        'user': Variable.get("rds_user", default_var="postgres"),
        'password': Variable.get("rds_password", default_var="password"),
    }
    
    return write_to_db(
        s3_bucket,
        top_ctr_file,
        top_product_file,
        db_config,
        execution_date
    )


task_db_writing = PythonOperator(
    task_id='db_writing',
    python_callable=task_db_writing_wrapper,
    dag=dag,
)


# Definir dependencias
task_filter_data >> [task_top_ctr, task_top_product] >> task_db_writing

