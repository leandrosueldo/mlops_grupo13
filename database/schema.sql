-- Esquema de base de datos para almacenar recomendaciones
-- Tabla para almacenar las recomendaciones de ambos modelos

CREATE TABLE IF NOT EXISTS recommendations (
    id SERIAL PRIMARY KEY,
    advertiser_id VARCHAR(50) NOT NULL,
    model_name VARCHAR(20) NOT NULL,  -- 'TopCTR' o 'TopProduct'
    product_id VARCHAR(50) NOT NULL,
    rank_position INTEGER NOT NULL,  -- Posición en el ranking (1-20)
    score FLOAT,  -- CTR para TopCTR, cantidad de vistas para TopProduct
    date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(advertiser_id, model_name, product_id, date)
);

-- Índices para mejorar las consultas
CREATE INDEX IF NOT EXISTS idx_recommendations_advertiser_model_date 
    ON recommendations(advertiser_id, model_name, date);
CREATE INDEX IF NOT EXISTS idx_recommendations_date 
    ON recommendations(date);

   select * from recommendations r 
   
   
   
   
   --pasar archivo PEM
   ssh -i ~/Downloads/airflow-grupo13-key.pem ec2-user@18.222.106.244
   
   # Activar entorno si no está activo
source ~/airflow-env/bin/activate
export AIRFLOW_HOME=~/airflow
export RDS_PASSWORD="Mimgrupo13"
export RDS_HOST="grupo-13-2025-rds.cpomi0gaon83.us-east-2.rds.amazonaws.com"

# Detener procesos
echo "🛑 Deteniendo procesos..."
pkill -9 -f "airflow" 2>/dev/null || true
pkill -9 -f "gunicorn" 2>/dev/null || true
sleep 3

# Actualizar configuración
echo "📝 Actualizando configuración..."
sed -i "s|sql_alchemy_conn = .*|sql_alchemy_conn = postgresql+psycopg2://postgres:${RDS_PASSWORD}@${RDS_HOST}:5432/mlops|g" ~/airflow/airflow.cfg

# Inicializar base de datos
echo "🗄️  Inicializando base de datos..."
airflow db migrate 2>&1 || airflow db init 2>&1

# Crear usuario admin
echo "👤 Creando usuario admin..."
airflow users create \
  --username admin \
  --firstname Admin \
  --lastname User \
  --role Admin \
  --email admin@example.com \
  --password admin 2>/dev/null || echo "Usuario admin ya existe"

# Iniciar webserver
echo "🚀 Iniciando webserver..."
cd ~/airflow
nohup airflow webserver -p 8080 > /tmp/airflow_webserver.log 2>&1 &
sleep 10

# Iniciar scheduler
echo "🚀 Iniciando scheduler..."
nohup airflow scheduler > /tmp/airflow_scheduler.log 2>&1 &
sleep 10

# Verificar
echo ""
echo "✅ Verificando servicios..."
ps aux | grep -E "(airflow|gunicorn)" | grep -v grep
echo ""
echo "✅ Verificando puerto 8080..."
ss -tlnp | grep 8080 || netstat -tlnp 2>/dev/null | grep 8080
echo ""
echo "✅ COMPLETADO!"
echo "Accede a: http://18.222.106.244:8080"

user y pass:
admin
admin 

hay que usar el ip de la instancia: la actual es http://18.222.106.244/


endpoints de apprunner:
# 1. Health Check
curl https://rybvxstvnd.us-east-2.awsapprunner.com/health

# 2. Recomendaciones TopCTR
curl https://rybvxstvnd.us-east-2.awsapprunner.com/recommendations/6X20RDH567MX2X3TXYJ7/TopCTR

# 3. Recomendaciones TopProduct
curl https://rybvxstvnd.us-east-2.awsapprunner.com/recommendations/6X20RDH567MX2X3TXYJ7/TopProduct

# 4. Estadísticas
curl https://rybvxstvnd.us-east-2.awsapprunner.com/stats/

# 5. Historial
curl https://rybvxstvnd.us-east-2.awsapprunner.com/history/6X20RDH567MX2X3TXYJ7/

documentacion: https://rybvxstvnd.us-east-2.awsapprunner.com/docs

#reconstruir y desplegar docker si hacemos cambios:
cd "/Users/tapiadmin/Documents/Posgrado MIM/Machine Learning Ops/MaterialTP/api"
docker build --platform linux/amd64 -t grupo13-recommendations-api:latest .
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 396913735447.dkr.ecr.us-east-2.amazonaws.com
docker tag grupo13-recommendations-api:latest 396913735447.dkr.ecr.us-east-2.amazonaws.com/grupo13-recommendations-api:latest
docker push 396913735447.dkr.ecr.us-east-2.amazonaws.com/grupo13-recommendations-api:latest

SELECT DISTINCT advertiser_id, date 
FROM recommendations 
ORDER BY date DESC 
LIMIT 10;


SELECT advertiser_id, model_name, COUNT(*) as count, MAX(date) as max_date
FROM recommendations
WHERE advertiser_id = '6X20RDH567MX2X3TXYJ7'
GROUP BY advertiser_id, model_name;



