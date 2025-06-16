#!/bin/bash

set -e

HEADER_FILE="params.h"
EXECUTABLE="./tiny_ising_cuda"

# 1. Leer parámetros desde el header
L=$(grep "#define L " $HEADER_FILE | awk '{print $3}')
TEMP_INITIAL=$(grep "#define TEMP_INITIAL" $HEADER_FILE | awk '{print $3}')
TEMP_FINAL=$(grep "#define TEMP_FINAL" $HEADER_FILE | awk '{print $3}')
TEMP_DELTA=$(grep "#define TEMP_DELTA" $HEADER_FILE | awk '{print $3}')

# 2. Calcular NPOINTS
NPOINTS=$(awk "BEGIN { printf(\"%.0f\", (($TEMP_FINAL - $TEMP_INITIAL) / $TEMP_DELTA) + 1) }")

echo "L = $L"
echo "TEMP_INITIAL = $TEMP_INITIAL"
echo "TEMP_FINAL = $TEMP_FINAL"
echo "TEMP_DELTA = $TEMP_DELTA"
echo "NPOINTS = $NPOINTS"
echo "-------------------------------------------"

# 3. Compilar CUDA (opcional, si no está compilado)
make tiny_ising_cuda

# 4. Correr con perf stat y capturar el tiempo real
PERF_OUTPUT=$(perf stat $EXECUTABLE 2>&1)

# 5. Extraer tiempo real (linea que contiene 'seconds time elapsed')
TIME=$(echo "$PERF_OUTPUT" | grep "seconds time elapsed" | grep -oP '^\s*\K[\d,]+')
TIME=${TIME/,/.}

if [[ -z "$TIME" ]]; then
    echo "Error: No se pudo obtener el tiempo real de perf."
    exit 1
fi

echo "Tiempo real: $TIME segundos"

# 6. Calcular métrica
METRICA=$(awk "BEGIN { printf(\"%.2f\", ($L * $L * $NPOINTS) / $TIME) }")

echo "-------------------------------------------"
echo "Métrica CUDA: (L^2 × NPOINTS) / Tiempo = $METRICA"
echo "-------------------------------------------"
