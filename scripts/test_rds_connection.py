#!/usr/bin/env python3
"""
Script para probar la conexión a RDS PostgreSQL
"""
import psycopg2
import sys

def test_connection(host, port, database, user, password):
    """Prueba la conexión a PostgreSQL"""
    try:
        print(f"Intentando conectar a {host}:{port}/{database}...")
        conn = psycopg2.connect(
            host=host,
            port=port,
            database=database,
            user=user,
            password=password
        )
        
        cursor = conn.cursor()
        cursor.execute("SELECT version();")
        version = cursor.fetchone()
        print(f"✓ Conexión exitosa!")
        print(f"  Versión PostgreSQL: {version[0]}")
        
        # Verificar si existe la tabla recommendations
        cursor.execute("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'recommendations'
            );
        """)
        table_exists = cursor.fetchone()[0]
        
        if table_exists:
            print("✓ Tabla 'recommendations' existe")
            cursor.execute("SELECT COUNT(*) FROM recommendations;")
            count = cursor.fetchone()[0]
            print(f"  Registros en la tabla: {count}")
        else:
            print("⚠ Tabla 'recommendations' NO existe")
            print("  Ejecuta: psql -h <host> -U <user> -d <database> -f database/schema.sql")
        
        cursor.close()
        conn.close()
        return True
        
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
    if len(sys.argv) < 6:
        print("Uso: python test_rds_connection.py <host> <port> <database> <user> <password>")
        print("Ejemplo: python test_rds_connection.py mlops-postgres.xxxxx.rds.amazonaws.com 5432 mlops postgres Mimgrupo13")
        sys.exit(1)
    
    host = sys.argv[1]
    port = int(sys.argv[2])
    database = sys.argv[3]
    user = sys.argv[4]
    password = sys.argv[5]
    
    success = test_connection(host, port, database, user, password)
    sys.exit(0 if success else 1)



