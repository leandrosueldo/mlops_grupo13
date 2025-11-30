#!/bin/bash
# Script para subir código a EC2 desde tu máquina local
# Ejecutar desde tu máquina local, NO desde EC2

EC2_IP="18.118.31.28"
KEY_PATH="$HOME/Downloads/airflow-grupo13-key.pem"
USER="ec2-user"  # Cambiar a "ubuntu" si es Ubuntu

# Verificar que el key existe
if [ ! -f "$KEY_PATH" ]; then
    echo "❌ Error: No se encuentra el archivo key en $KEY_PATH"
    echo "   Ajusta la ruta en el script o coloca el archivo .pem en esa ubicación"
    exit 1
fi

# Dar permisos al key
chmod 400 "$KEY_PATH"

echo "Subiendo código a EC2..."
echo ""

# Aceptar host key automáticamente
ssh-keyscan -H ${EC2_IP} >> ~/.ssh/known_hosts 2>/dev/null || true

# Subir directorio airflow
echo "📤 Subiendo directorio airflow..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no -r airflow/ ${USER}@${EC2_IP}:~/ 2>/dev/null || {
    echo "⚠️  Error subiendo airflow, intentando de nuevo..."
    scp -i "$KEY_PATH" -o StrictHostKeyChecking=accept-new -r airflow/ ${USER}@${EC2_IP}:~/
}

# Subir scripts
echo "📤 Subiendo scripts..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no scripts/*.sh ${USER}@${EC2_IP}:~/ 2>/dev/null || true

# Subir scripts de Python
echo "📤 Subiendo scripts de Python..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no scripts/*.py ${USER}@${EC2_IP}:~/ 2>/dev/null || true

# Subir schema
echo "📤 Subiendo schema de base de datos..."
scp -i "$KEY_PATH" -o StrictHostKeyChecking=no -r database/ ${USER}@${EC2_IP}:~/ 2>/dev/null || true

echo ""
echo "✅ Código subido exitosamente!"
echo ""
echo "Ahora conecta a EC2 y ejecuta el script de instalación:"
echo "  ssh -i $KEY_PATH ${USER}@${EC2_IP}"
echo "  bash ~/install_airflow_ec2.sh"

