# Trabajo Práctico MLOps - Sistema de Recomendaciones AdTech

Este proyecto implementa un sistema completo de recomendaciones de productos para una plataforma AdTech, utilizando Airflow para el procesamiento de datos, FastAPI para la API y PostgreSQL en AWS RDS para el almacenamiento.

## Estructura del Proyecto

```
MaterialTP/
├── airflow/
│   ├── dags/
│   │   └── recommendations_pipeline.py  # DAG principal de Airflow
│   ├── scripts/
│   │   ├── filter_data.py                # Filtra datos por advertisers activos
│   │   ├── top_ctr.py                    # Calcula TopCTR
│   │   ├── top_product.py                # Calcula TopProduct
│   │   └── db_writing.py                 # Escribe resultados en PostgreSQL
│   └── requirements.txt
├── api/
│   ├── app/
│   │   └── main.py                       # API FastAPI
│   ├── Dockerfile                        # Dockerfile para la API
│   └── requirements.txt
├── database/
│   └── schema.sql                        # Esquema de base de datos
├── GenerateTPData.ipynb                  # Notebook para generar datos de prueba
└── README.md
```

## Componentes del Sistema

### 1. Pipeline de Datos (Airflow)

El pipeline se ejecuta diariamente y realiza las siguientes tareas:

1. **FiltrarDatos**: Filtra los logs del día para mantener solo advertisers activos
2. **TopCTR**: Calcula los 20 productos con mejor Click-Through-Rate por advertiser
3. **TopProduct**: Calcula los 20 productos más vistos por advertiser
4. **DBWriting**: Escribe los resultados en PostgreSQL

### 2. API (FastAPI)

La API expone los siguientes endpoints:

- `GET /recommendations/{advertiser_id}/{model_name}`: Obtiene recomendaciones del día
- `GET /stats/`: Estadísticas sobre las recomendaciones
- `GET /history/{advertiser_id}/`: Historial de recomendaciones (últimos 7 días)
- `GET /health`: Health check

### 3. Base de Datos (PostgreSQL)

Almacena las recomendaciones generadas por ambos modelos con la siguiente estructura:
- `advertiser_id`: ID del advertiser
- `model_name`: 'TopCTR' o 'TopProduct'
- `product_id`: ID del producto recomendado
- `rank_position`: Posición en el ranking (1-20)
- `score`: CTR o cantidad de vistas según el modelo
- `date`: Fecha de la recomendación

## Configuración e Instalación

### Prerrequisitos

- Cuenta de AWS con acceso a:
  - EC2 (para Airflow)
  - S3 (para almacenar datos)
  - RDS (para PostgreSQL)
  - App Runner (para la API)
- Python 3.12+
- Docker (para la API)

### 1. Generar Datos de Prueba

Ejecuta el notebook `GenerateTPData.ipynb` para generar los archivos:
- `advertiser_ids`: Lista de advertisers activos
- `product_views`: Logs de vistas de productos
- `ads_views`: Logs de vistas de ads

### 2. Configurar S3

1. Crea un bucket en S3 (ej: `mlops-tp-bucket`)
2. Sube los archivos generados:
   ```
   raw_data/
   ├── advertiser_ids
   ├── product_views
   └── ads_views
   ```

### 3. Configurar RDS

1. Crea una instancia PostgreSQL en AWS RDS
2. Ejecuta el esquema de base de datos:
   ```bash
   psql -h <rds-endpoint> -U <usuario> -d <database> -f database/schema.sql
   ```

### 4. Configurar Airflow en EC2

1. **Crear instancia EC2** (recomendado: t2.small)
2. **Instalar dependencias**:
   ```bash
   sudo apt-get update
   sudo apt-get install python3-pip python3-venv postgresql-client
   ```

3. **Instalar Airflow**:
   ```bash
   python3 -m venv airflow-env
   source airflow-env/bin/activate
   pip install -r airflow/requirements.txt
   ```

4. **Configurar Airflow**:
   - Edita `airflow.cfg` y configura la conexión a PostgreSQL:
     ```ini
     [database]
     sql_alchemy_conn = postgresql+psycopg2://usuario:contraseña@rds-endpoint:5432/database
     ```

5. **Configurar Variables de Airflow**:
   Desde la UI de Airflow (Admin > Variables) o usando CLI:
   ```bash
   airflow variables set s3_bucket "mlops-tp-bucket"
   airflow variables set s3_input_prefix "raw_data"
   airflow variables set s3_output_prefix "processed_data"
   airflow variables set advertiser_ids_file "raw_data/advertiser_ids"
   airflow variables set rds_host "tu-rds-endpoint"
   airflow variables set rds_port "5432"
   airflow variables set rds_database "mlops"
   airflow variables set rds_user "postgres"
   airflow variables set rds_password "tu-password"
   ```

6. **Configurar credenciales de AWS**:
   ```bash
   aws configure
   ```

7. **Inicializar base de datos de Airflow**:
   ```bash
   airflow db init
   ```

8. **Crear usuario administrador**:
   ```bash
   airflow users create \
     --username admin \
     --firstname Admin \
     --lastname User \
     --role Admin \
     --email admin@example.com \
     --password admin
   ```

9. **Iniciar servicios** (como daemon):
   ```bash
   airflow webserver -D
   airflow scheduler -D
   ```

### 5. Desplegar API en App Runner

1. **Construir imagen Docker**:
   ```bash
   cd api
   docker build -t recommendations-api .
   ```

2. **Probar localmente** (opcional):
   ```bash
   docker run -p 8000:8000 \
     -e RDS_HOST=tu-rds-endpoint \
     -e RDS_PORT=5432 \
     -e RDS_DATABASE=mlops \
     -e RDS_USER=postgres \
     -e RDS_PASSWORD=tu-password \
     recommendations-api
   ```

3. **Subir a ECR y desplegar en App Runner**:
   - Crea un repositorio en Amazon ECR
   - Sube la imagen Docker
   - Crea un servicio en App Runner apuntando a la imagen
   - Configura las variables de entorno para la conexión a RDS

## Uso

### Ejecutar el Pipeline

El pipeline se ejecuta automáticamente todos los días a las 2 AM. También puedes ejecutarlo manualmente desde la UI de Airflow.

### Usar la API

Una vez desplegada, puedes hacer requests a los endpoints:

```bash
# Obtener recomendaciones
curl https://tu-api-url/recommendations/ADV123/TopCTR

# Obtener estadísticas
curl https://tu-api-url/stats/

# Obtener historial
curl https://tu-api-url/history/ADV123/
```

## Solución de Problemas

### No se puede acceder a Airflow (ERR_CONNECTION_REFUSED)

**Problema**: No puedes acceder a http://18.118.31.28:8080

**Solución rápida**:
1. Verifica el Security Group de EC2 y asegúrate de que el puerto 8080 esté abierto:
   ```bash
   ./scripts/configurar_security_group.sh
   ```

2. Reinicia los servicios de Airflow en EC2:
   ```bash
   # Opción A: Desde tu máquina (si tienes acceso SSH)
   ./scripts/fix_airflow_complete.sh
   
   # Opción B: Conectarte a EC2 y ejecutar allí
   ssh -i ~/Downloads/airflow-grupo13-key.pem ec2-user@18.118.31.28
   # Luego sube y ejecuta: scripts/fix_airflow_on_ec2.sh
   ```

3. Verifica el estado:
   ```bash
   ./scripts/verificar_airflow.sh
   ```

**Ver documentación completa**: Ver `SOLUCIONAR_AIRFLOW.md`

### Scheduler no está corriendo

**Problema**: El scheduler no procesa tareas o aparece el warning "The scheduler does not appear to be running"

**Solución**:
1. Reinicia el scheduler siguiendo los pasos de arriba
2. Espera 1-2 minutos después de reiniciar (el scheduler necesita tiempo para sincronizar)
3. Verifica los logs: `tail -f /tmp/airflow_scheduler.log`

### Airflow no encuentra los scripts

Asegúrate de que el path en el DAG sea correcto. El DAG busca los scripts en `airflow/scripts/` relativo al directorio del DAG.

### Error de conexión a RDS

- Verifica que el Security Group de RDS permita conexiones desde tu instancia EC2
- Verifica las credenciales y el endpoint de RDS
- Asegúrate de que la base de datos esté creada y el esquema ejecutado

### Error de acceso a S3

- Verifica las credenciales de AWS configuradas
- Verifica los permisos del IAM role/user
- Verifica que el bucket exista y los archivos estén en las rutas correctas

## Notas Importantes

- Todos los servicios de AWS utilizados entran en el free tier o tienen costos muy bajos
- Revisa periódicamente los costos en AWS Console
- El pipeline procesa datos del día anterior por defecto (usando `{{ ds }}`)
- Las recomendaciones se actualizan diariamente después de la ejecución del pipeline

## Entregables

Para la entrega del trabajo práctico necesitas:

1. **Código en repositorio**: Todo el código debe estar en un repositorio Git
2. **Servicios levantados**: Los servicios deben estar disponibles para corrección
3. **Informe**: Documentar pasos importantes y dificultades encontradas

## Fecha Límite

- **Entrega de código e informe**: Lunes 15 de diciembre a las 23:59hs
- **Disponibilización de servicios**: Coordinar con el corrector para el Jueves 18 de diciembre

