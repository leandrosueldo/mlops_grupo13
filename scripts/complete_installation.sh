#!/bin/bash
# Script para completar la instalación de Airflow
# Ejecutar DESDE DENTRO de EC2

set +e  # Continuar aunque haya errores

export AIRFLOW_HOME=~/airflow
source ~/airflow-env/bin/activate

echo "Completando instalación de Airflow..."
echo ""

# Verificar si Airflow está instalado
if ! command -v airflow &> /dev/null; then
    echo "Instalando Airflow y dependencias..."
    pip install apache-airflow==2.7.3 pandas==2.1.3 boto3==1.29.7 psycopg2-binary==2.9.9 --quiet
    echo "✅ Dependencias instaladas"
else
    echo "✅ Airflow ya está instalado"
fi

# Configurar Airflow
echo ""
echo "Configurando Airflow..."
mkdir -p $AIRFLOW_HOME

# Configurar conexión a PostgreSQL
RDS_ENDPOINT="mimgrupo13.cpomi0gaon83.us-east-2.rds.amazonaws.com"
SQL_ALCHEMY_CONN="postgresql+psycopg2://postgres:Mimgrupo13@${RDS_ENDPOINT}:5432/mlops"

# Inicializar si no existe
if [ ! -f $AIRFLOW_HOME/airflow.cfg ]; then
    airflow db init
fi

# Configurar PostgreSQL
sed -i "s|sql_alchemy_conn = sqlite:///.*|sql_alchemy_conn = ${SQL_ALCHEMY_CONN}|" $AIRFLOW_HOME/airflow.cfg

# Reinicializar con PostgreSQL
rm -f $AIRFLOW_HOME/airflow.db
airflow db init

echo "✅ Airflow configurado con PostgreSQL"

# Crear usuario admin
echo ""
echo "Creando usuario administrador..."
airflow users create \
  --username admin \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com \
  --password admin \
  2>/dev/null || echo "Usuario admin ya existe"

# Configurar variables
echo ""
echo "Configurando variables de Airflow..."
airflow variables set s3_bucket "grupo13-2025"
airflow variables set s3_input_prefix "raw_data"
airflow variables set s3_output_prefix "processed_data"
airflow variables set advertiser_ids_file "raw_data/advertiser_ids"
airflow variables set rds_host "$RDS_ENDPOINT"
airflow variables set rds_port "5432"
airflow variables set rds_database "mlops"
airflow variables set rds_user "postgres"
airflow variables set rds_password "Mimgrupo13"

echo "✅ Variables configuradas"

# Copiar DAGs y scripts
echo ""
echo "Configurando DAGs y scripts..."
mkdir -p $AIRFLOW_HOME/dags
mkdir -p $AIRFLOW_HOME/scripts

if [ -f ~/airflow/dags/recommendations_pipeline.py ]; then
    cp ~/airflow/dags/recommendations_pipeline.py $AIRFLOW_HOME/dags/
fi

if [ -d ~/airflow/scripts ]; then
    cp ~/airflow/scripts/*.py $AIRFLOW_HOME/scripts/ 2>/dev/null || true
fi

echo "✅ DAGs y scripts configurados"

# Crear schema en RDS
echo ""
echo "Creando schema en RDS..."
python3 << 'EOF'
import psycopg2
try:
    conn = psycopg2.connect(
        host='mimgrupo13.cpomi0gaon83.us-east-2.rds.amazonaws.com',
        port=5432,
        database='mlops',
        user='postgres',
        password='Mimgrupo13'
    )
    cursor = conn.cursor()
    
    schema_sql = '''
    CREATE TABLE IF NOT EXISTS recommendations (
        id SERIAL PRIMARY KEY,
        advertiser_id VARCHAR(50) NOT NULL,
        model_name VARCHAR(20) NOT NULL,
        product_id VARCHAR(50) NOT NULL,
        rank_position INTEGER NOT NULL,
        score FLOAT,
        date DATE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(advertiser_id, model_name, product_id, date)
    );
    
    CREATE INDEX IF NOT EXISTS idx_recommendations_advertiser_model_date 
        ON recommendations(advertiser_id, model_name, date);
    CREATE INDEX IF NOT EXISTS idx_recommendations_date 
        ON recommendations(date);
    '''
    
    cursor.execute(schema_sql)
    conn.commit()
    print("✅ Schema creado en RDS")
    cursor.close()
    conn.close()
except Exception as e:
    print(f"⚠️  Error creando schema: {e}")
EOF

echo ""
echo "=========================================="
echo "✅ Instalación completada!"
echo "=========================================="
echo ""
echo "Para iniciar Airflow:"
echo "  source ~/airflow-env/bin/activate"
echo "  export AIRFLOW_HOME=~/airflow"
echo "  bash ~/start_airflow.sh"
echo ""



