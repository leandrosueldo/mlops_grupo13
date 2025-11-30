#!/usr/bin/env python3
"""
Script para crear el esquema de base de datos en RDS
"""
import psycopg2
import sys
import os

def create_schema(host, port, database, user, password):
    """Crea el esquema de base de datos"""
    try:
        print(f"Conectando a {host}:{port}/{database}...")
        conn = psycopg2.connect(
            host=host,
            port=port,
            database=database,
            user=user,
            password=password
        )
        
        cursor = conn.cursor()
        
        # Leer y ejecutar schema
        schema_path = os.path.join(os.path.dirname(__file__), '..', 'database', 'schema.sql')
        with open(schema_path, 'r') as f:
            schema_sql = f.read()
        
        print("Ejecutando schema...")
        cursor.execute(schema_sql)
        conn.commit()
        
        # Verificar que la tabla se creó
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'recommendations'
            );
        """)
        table_exists = cursor.fetchone()[0]
        
        if table_exists:
            print("✓ Schema creado exitosamente!")
            print("✓ Tabla 'recommendations' existe")
        else:
            print("⚠ Schema ejecutado pero la tabla no se encontró")
        
        cursor.close()
        conn.close()
        return True
        
    except FileNotFoundError:
        print(f"✗ Error: No se encontró el archivo schema.sql en {schema_path}")
        return False
    except psycopg2.OperationalError as e:
        print(f"✗ Error de conexión: {e}")
        print("\nPosibles causas:")
        print("  - Security Group de RDS no permite conexiones desde tu IP")
        print("  - Endpoint incorrecto")
        print("  - Credenciales incorrectas")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python create_schema.py <rds_endpoint> [port] [database] [user] [password]")
        print("Ejemplo: python create_schema.py mlops-postgres.xxxxx.rds.amazonaws.com")
        print("         python create_schema.py mlops-postgres.xxxxx.rds.amazonaws.com 5432 mlops postgres Mimgrupo13")
        sys.exit(1)
    
    host = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 5432
    database = sys.argv[3] if len(sys.argv) > 3 else 'mlops'
    user = sys.argv[4] if len(sys.argv) > 4 else 'postgres'
    password = sys.argv[5] if len(sys.argv) > 5 else 'Mimgrupo13'
    
    success = create_schema(host, port, database, user, password)
    sys.exit(0 if success else 1)



