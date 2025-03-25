#!/bin/bash

HEADER_FILE="params.h"
EXECUTABLE="./tiny_ising"
SRC_BACKUP="params.h.bak"

# Rangos de valores
L_values=(384 500 800)
TEMP_FINAL_values=(2.0 3.0 5.0)

# Backup del archivo original
cp "$HEADER_FILE" "$SRC_BACKUP"

# Función para modificar un parámetro en el archivo header
modify_param() {
    param=$1
    value=$2
    sed -i "s/#define $param .*/#define $param $value/" "$HEADER_FILE"
}

run() {
    COMPILER=$1
    CFLAGS=$2
    LDFLAGS_EXTRA=$3
    COMMENT=$4

    echo "Compilando con: $COMPILER $CFLAGS $LDFLAGS_EXTRA ($COMMENT)" >&2

    make clean > /dev/null 2>&1

    # Compilar con los flags dados
    make CC="$COMPILER" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS_EXTRA -lm" tiny_ising > /dev/null 2>&1

    if [[ ! -f $EXECUTABLE ]]; then
        echo "ERROR: Falló la compilación con $COMPILER $CFLAGS" >&2
        echo "N/A;$COMMENT;ERROR_COMPILACION"
        return
    fi

    # Leer parámetros desde el header
    L=$(grep "#define L " $HEADER_FILE | awk '{print $3}')
    TEMP_INITIAL=$(grep "#define TEMP_INITIAL" $HEADER_FILE | awk '{print $3}')
    TEMP_FINAL=$(grep "#define TEMP_FINAL" $HEADER_FILE | awk '{print $3}')
    TEMP_DELTA=$(grep "#define TEMP_DELTA" $HEADER_FILE | awk '{print $3}')
    NPOINTS=$(awk "BEGIN { printf(\"%.0f\", (($TEMP_FINAL - $TEMP_INITIAL) / $TEMP_DELTA) + 1) }")

    # Ejecutar y capturar tiempo - usando time si perf no funciona
    if command -v perf >/dev/null 2>&1; then
        TIME_COMMAND="perf stat"
    else
        TIME_COMMAND="/usr/bin/time"
    fi

    EXEC_OUTPUT=$($TIME_COMMAND $EXECUTABLE 2>&1)
    
    if [[ "$TIME_COMMAND" == "perf stat" ]]; then
        TIME=$(echo "$EXEC_OUTPUT" | grep "seconds time elapsed" | grep -oP '^\s*\K[\d,]+' | head -1)
    else
        # Formato de time: "real 0m1.234s"
        TIME=$(echo "$EXEC_OUTPUT" | grep -oP 'real\s+\d+m\d+\.\d+s' | sed 's/real //;s/m/./;s/s//')
    fi

    # Convertir tiempo a segundos (para el formato de time)
    if [[ "$TIME" == *m* ]]; then
        MINUTES=$(echo "$TIME" | cut -d'm' -f1)
        SECONDS=$(echo "$TIME" | cut -d'm' -f2 | cut -d's' -f1)
        TIME=$(awk "BEGIN { print $MINUTES * 60 + $SECONDS }")
    fi

    # Reemplazar coma por punto para locales que usan coma decimal
    TIME=${TIME//,/.}

    if [[ -z "$TIME" ]] || [[ "$TIME" == "0" ]]; then
        echo "ERROR: No se pudo obtener el tiempo de ejecución" >&2
        echo "N/A;$COMMENT;ERROR_TIEMPO"
        return
    fi

    # Calcular la métrica
    METRICA=$(awk "BEGIN { printf(\"%.2f\", ($L * $L * $NPOINTS) / $TIME) }" 2>/dev/null)
    
    if [[ -z "$METRICA" ]]; then
        echo "ERROR: Cálculo de métrica falló" >&2
        echo "N/A;$COMMENT;ERROR_CALCULO"
    else
        echo "$METRICA;$COMMENT;L=$L;TEMP_FINAL=$TEMP_FINAL;NPOINTS=$NPOINTS"
    fi
}

# Encabezado del output
echo "Métrica;Compilador;L;TEMP_FINAL;NPOINTS;NOTAS"

# Probar diferentes combinaciones de L y TEMP_FINAL
for L in "${L_values[@]}"; do
    for TEMP_FINAL in "${TEMP_FINAL_values[@]}"; do
        # Modificar los parámetros en el archivo
        modify_param "L" "$L"
        modify_param "TEMP_FINAL" "$TEMP_FINAL"
        
        # Ejecutar la prueba
        run gcc-12 "-Ofast" "" "Optimización Ofast"
    done
done

# Restaurar el archivo original
mv "$SRC_BACKUP" "$HEADER_FILE"
