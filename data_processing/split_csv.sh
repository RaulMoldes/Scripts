#!/bin/bash

# Verificar que los argumentos sean correctos
if [ "$#" -ne 3 ]; then
    echo "Uso: $0 <archivo_entrada> <tamano_max_kb> <prefijo_salida>"
    echo "Ejemplo: $0 /home/admin/data.csv 32 data-"
    exit 1
fi

# Asignar parámetros
INPUT_FILE="$1"
SIZE_LIMIT_KB="$2"
OUTPUT_PREFIX="$3"
HEADER_FILE="header.tmp"

# Verificar si el archivo de entrada existe
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: El archivo '$INPUT_FILE' no existe."
    exit 1
fi
# Extraer el header
head -n 1 "$INPUT_FILE" > "$HEADER_FILE"

# Calcular el tamaño del header en bytes
HEADER_SIZE=$(stat -c %s "$HEADER_FILE")

# Calcular el tamaño real permitido por archivo
DATA_SIZE=$((32 * 1024 - HEADER_SIZE))

# Verificar que el tamaño sea positivo (por si el header es muy grande)
if [ "$DATA_SIZE" -le 0 ]; then
    echo "Error: El header es demasiado grande para este límite de 32KB."
    exit 1
fi

# Quitar el header del archivo original y dividir respetando el tamaño calculado
tail -n +2 "$INPUT_FILE" | split -d -b "$DATA_SIZE" --additional-suffix=.csv - "$OUTPUT_PREFIX"

# Añadir el header a cada archivo dividido
for FILE in ${OUTPUT_PREFIX}*.csv; do
    (cat "$HEADER_FILE"; cat "$FILE") > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
done

# Limpiar archivo temporal
rm "$HEADER_FILE"

echo "Archivos divididos correctamente en fragmentos cada uno de máximo 32KB."