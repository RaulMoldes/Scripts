#!/bin/bash

# Verificar argumentos
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <prefijo_entrada> <archivo_salida>"
    echo "Ejemplo: $0 data/ data_reunido.csv"
    exit 1
fi

# Asignar parámetros
INPUT_PREFIX="$1"
OUTPUT_FILE="$2"
TEMP_FILE="temp_file.tmp"

if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: El prefijo de entrada '$INPUT_DIR' no es un directorio válido."
    exit 1
fi

# Buscar archivos que coincidan con el prefijo y sean .csv
CSV_FILES=$(ls "${INPUT_PREFIX}"*.csv 2>/dev/null)

# Verificar si existen archivos con el prefijo
if [ -z "$CSV_FILES" ]; then
    echo "Error: No se encontraron archivos con el prefijo '${INPUT_PREFIX}'."
    exit 1
fi

# Extraer el header del primer archivo encontrado
FIRST_FILE=$(echo "$CSV_FILES" | head -n 1)
head -n 1 "$FIRST_FILE" > "$OUTPUT_FILE"

# Añadir el contenido de todos los archivos sin duplicar el header
for FILE in $CSV_FILES; do
    tail -n +2 "$FILE" >> "$OUTPUT_FILE"
done

echo "Archivos con prefijo '$INPUT_PREFIX' unidos en '$OUTPUT_FILE'."