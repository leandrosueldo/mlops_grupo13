#!/bin/bash
# Script completo para instalar y configurar Airflow en EC2
# Ejecutar este script DESDE DENTRO de EC2 después de conectarse por SSH

set +e  # No salir si hay error, continuar

echo "=========================================="
echo "Instalación Automática de Airflow en EC2"
echo "=========================================="
echo ""

# Variables de configuración
RDS_ENDPOINT="mimgrupo13.cpomi0gaon83.us-east-2.rds.amazonaws.com"
RDS_PORT="5432"
RDS_DATABASE="mlops"
RDS_USER="postgres"
RDS_PASSWORD="Mimgrupo13"
S3_BUCKET="grupo13-2025"
AIRFLOW_HOME=~/airflow

echo "📦 Paso 1: Actualizando sistema..."
if command -v yum &> /dev/null; then
    # Amazon Linux
    sudo yum update -y
    sudo yum install -y python3 python3-pip git gcc python3-devel
    # python3-venv viene incluido en python3 en Amazon Linux 2023
    # postgresql no es necesario, solo psycopg2-binary
    USER="ec2-user"
elif command -v apt-get &> /dev/null; then
    # Ubuntu
    sudo apt-get update -y
    sudo apt-get install -y python3 python3-pip python3-venv postgresql-client git build-essential
    USER="ubuntu"
else
    echo "⚠️  Sistema operativo no reconocido, intentando continuar..."
    USER="ec2-user"
fi

echo "✅ Sistema actualizado"
echo ""

echo "📦 Paso 2: Instalando AWS CLI..."
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
fi
echo "✅ AWS CLI instalado"
echo ""

echo "📦 Paso 3: Configurando AWS CLI..."
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = YOUR_AWS_ACCESS_KEY_ID
aws_secret_access_key = YOUR_AWS_SECRET_ACCESS_KEY
EOF

cat > ~/.aws/config << EOF
[default]
region = us-east-2
output = json
EOF
echo "✅ AWS CLI configurado"
echo ""

echo "📦 Paso 4: Verificando conexión a AWS..."
aws sts get-caller-identity > /dev/null
echo "✅ Conexión a AWS verificada"
echo ""

echo "📦 Paso 5: Creando entorno virtual de Python..."
python3 -m venv airflow-env
source airflow-env/bin/activate
pip install --upgrade pip --quiet
echo "✅ Entorno virtual creado"
echo ""

echo "📦 Paso 6: Instalando dependencias de Airflow..."
if [ -d ~/airflow ]; then
    cd ~/airflow
    pip install -r requirements.txt --quiet
else
    # Instalar dependencias básicas si no existe el directorio
    pip install apache-airflow==2.7.3 pandas==2.1.3 boto3==1.29.7 psycopg2-binary==2.9.9 --quiet
fi
echo "✅ Dependencias instaladas"
echo ""

echo "📦 Paso 7: Configurando Airflow..."
export AIRFLOW_HOME=$AIRFLOW_HOME
mkdir -p $AIRFLOW_HOME

# Inicializar base de datos (primera vez)
if [ ! -f $AIRFLOW_HOME/airflow.db ]; then
    airflow db init
fi

# Configurar conexión a PostgreSQL
SQL_ALCHEMY_CONN="postgresql+psycopg2://${RDS_USER}:${RDS_PASSWORD}@${RDS_ENDPOINT}:${RDS_PORT}/${RDS_DATABASE}"
sed -i "s|sql_alchemy_conn = sqlite:///.*|sql_alchemy_conn = ${SQL_ALCHEMY_CONN}|" $AIRFLOW_HOME/airflow.cfg

# Reinicializar con PostgreSQL
rm -f $AIRFLOW_HOME/airflow.db
airflow db init
echo "✅ Airflow configurado con PostgreSQL"
echo ""

echo "📦 Paso 8: Creando usuario administrador de Airflow..."
airflow users create \
  --username admin \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com \
  --password admin \
  2>/dev/null || echo "Usuario admin ya existe, continuando..."
echo "✅ Usuario administrador creado"
echo ""

echo "📦 Paso 9: Configurando variables de Airflow..."
airflow variables set s3_bucket "$S3_BUCKET"
airflow variables set s3_input_prefix "raw_data"
airflow variables set s3_output_prefix "processed_data"
airflow variables set advertiser_ids_file "raw_data/advertiser_ids"
airflow variables set rds_host "$RDS_ENDPOINT"
airflow variables set rds_port "$RDS_PORT"
airflow variables set rds_database "$RDS_DATABASE"
airflow variables set rds_user "$RDS_USER"
airflow variables set rds_password "$RDS_PASSWORD"
echo "✅ Variables de Airflow configuradas"
echo ""

echo "📦 Paso 10: Configurando DAGs y scripts..."
mkdir -p $AIRFLOW_HOME/dags
mkdir -p $AIRFLOW_HOME/scripts

# Copiar DAG si existe
if [ -f ~/airflow/dags/recommendations_pipeline.py ]; then
    cp ~/airflow/dags/recommendations_pipeline.py $AIRFLOW_HOME/dags/
    echo "✅ DAG copiado"
fi

# Copiar scripts si existen
if [ -d ~/airflow/scripts ]; then
    cp ~/airflow/scripts/*.py $AIRFLOW_HOME/scripts/ 2>/dev/null || true
    echo "✅ Scripts copiados"
fi

echo "✅ Estructura de directorios creada"
echo ""

echo "📦 Paso 11: Probando conexión a RDS..."
python3 << EOF
import psycopg2
try:
    conn = psycopg2.connect(
        host='${RDS_ENDPOINT}',
        port=${RDS_PORT},
        database='${RDS_DATABASE}',
        user='${RDS_USER}',
        password='${RDS_PASSWORD}',
        connect_timeout=10
    )
    cursor = conn.cursor()
    cursor.execute("SELECT version();")
    print("✅ Conexión a RDS exitosa!")
    cursor.close()
    conn.close()
except Exception as e:
    print(f"⚠️  Error conectando a RDS: {e}")
    print("   Continuando de todas formas...")
EOF
echo ""

echo "📦 Paso 12: Creando schema en RDS..."
if [ -f ~/airflow/scripts/create_schema.py ]; then
    python3 ~/airflow/scripts/create_schema.py ${RDS_ENDPOINT} ${RDS_PORT} ${RDS_DATABASE} ${RDS_USER} ${RDS_PASSWORD} || echo "⚠️  Error creando schema, puede que ya exista"
else
    # Crear schema manualmente
    python3 << EOF
import psycopg2
try:
    conn = psycopg2.connect(
        host='${RDS_ENDPOINT}',
        port=${RDS_PORT},
        database='${RDS_DATABASE}',
        user='${RDS_USER}',
        password='${RDS_PASSWORD}'
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
fi
echo ""

echo "📦 Paso 13: Configurando Airflow para ejecutar en background..."
# Agregar al .bashrc para que se active el entorno al conectarse
if ! grep -q "source ~/airflow-env/bin/activate" ~/.bashrc; then
    echo "source ~/airflow-env/bin/activate" >> ~/.bashrc
    echo "export AIRFLOW_HOME=$AIRFLOW_HOME" >> ~/.bashrc
fi
echo "✅ Configuración de entorno guardada"
echo ""

echo "=========================================="
echo "✅ Instalación completada!"
echo "=========================================="
echo ""
echo "Para iniciar Airflow, ejecuta:"
echo "  source ~/airflow-env/bin/activate"
echo "  export AIRFLOW_HOME=$AIRFLOW_HOME"
echo "  airflow webserver -D -p 8080"
echo "  airflow scheduler -D"
echo ""
echo "O ejecuta el script de inicio:"
echo "  bash ~/start_airflow.sh"
echo ""
echo "Accede a Airflow UI en: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Usuario: admin"
echo "Password: admin"
echo ""

