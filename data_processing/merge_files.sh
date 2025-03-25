#!/bin/bash

# Verificar argumentos
if [ "$#" -ne 3 ]; then
    echo "Uso: $0 <directorio_entrada> <extension_archivo> <archivo_salida>"
    echo "Ejemplo: $0 /home/admin/data/ yaml archivos_unidos.yaml"
    exit 1
fi

# Asignar parámetros
INPUT_DIR="$1"
FILE_EXTENSION="$2"
OUTPUT_FILE="$3"

# Verificar si el directorio existe y es un directorio
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: El prefijo de entrada '$INPUT_DIR' no es un directorio válido."
    exit 1
fi

# Buscar archivos con la extensión especificada
FILES=$(find "$INPUT_DIR" -type f -name "*.$FILE_EXTENSION")

# Verificar si se encontraron archivos con la extensión especificada
if [ -z "$FILES" ]; then
    echo "Error: No se encontraron archivos con la extensión '.$FILE_EXTENSION' en el directorio '$INPUT_DIR'."
    exit 1
fi

# Crear o limpiar el archivo de salida
> "$OUTPUT_FILE"

# Unir el contenido de todos los archivos en el archivo de salida
for FILE in $FILES; do
    # Añadir un separador entre archivos (opcional)
    echo -e "\n\n# --- Contenido de '$FILE' ---\n" >> "$OUTPUT_FILE"
    
    # Añadir el contenido del archivo al archivo de salida
    cat "$FILE" >> "$OUTPUT_FILE"
done

echo "Archivos con extensión '.$FILE_EXTENSION' del directorio '$INPUT_DIR' unidos en '$OUTPUT_FILE'."
