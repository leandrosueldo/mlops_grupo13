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
        
        # Leer el archivo schema.sql
        schema_path = os.path.join(os.path.dirname(__file__), '..', 'database', 'schema.sql')
        if not os.path.exists(schema_path):
            print(f"✗ Error: No se encuentra el archivo {schema_path}")
            return False
        
        print(f"Leyendo schema desde {schema_path}...")
        with open(schema_path, 'r') as f:
            schema_sql = f.read()
        
        # Ejecutar el schema
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
            print("✓ Tabla 'recommendations' creada exitosamente")
            
            # Verificar índices
            cursor.execute("""
                SELECT indexname FROM pg_indexes 
                WHERE tablename = 'recommendations';
            """)
            indexes = [row[0] for row in cursor.fetchall()]
            print(f"✓ Índices creados: {len(indexes)}")
            for idx in indexes:
                print(f"  - {idx}")
        else:
            print("⚠ Advertencia: La tabla no se encontró después de crear el schema")
        
        cursor.close()
        conn.close()
        print("\n✓ Schema creado correctamente!")
        return True
        
    except psycopg2.OperationalError as e:
        print(f"✗ Error de conexión: {e}")
        print("\nVerifica:")
        print("  - Security Group de RDS permite conexiones")
        print("  - Endpoint correcto")
        print("  - Credenciales correctas")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    if len(sys.argv) < 6:
        print("Uso: python create_schema_rds.py <host> <port> <database> <user> <password>")
        print("\nEjemplo:")
        print("  python create_schema_rds.py grupo-13-2025-rds.cpomi0gaon83.us-east-2.rds.amazonaws.com 5432 mlops postgres Mimgrupo13")
        sys.exit(1)
    
    host = sys.argv[1]
    port = int(sys.argv[2])
    database = sys.argv[3]
    user = sys.argv[4]
    password = sys.argv[5]
    
    success = create_schema(host, port, database, user, password)
    sys.exit(0 if success else 1)

