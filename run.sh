#!/bin/bash

HEADER_FILE="params.h"
EXECUTABLE="./tiny_ising"
OUTPUT=""

run() {
    COMPILER=$1
    CFLAGS=$2
    LDFLAGS_EXTRA=$3
    COMMENT=$4

    echo "Compilando con: $COMPILER $CFLAGS $LDFLAGS_EXTRA ($COMMENT)"

    make clean > /dev/null

    # Compilar con los flags dados
    make CC="$COMPILER" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS_EXTRA -lm -fopenmp" tiny_ising > /dev/null 2>&1

    if [[ ! -f $EXECUTABLE ]]; then
        echo "ERROR: Falló la compilación con $COMPILER $CFLAGS"
        OUTPUT="N/A;$COMMENT"
        return
    fi

    # Leer parámetros desde el header
    L=$(grep "#define L " $HEADER_FILE | awk '{print $3}')
    TEMP_INITIAL=$(grep "#define TEMP_INITIAL" $HEADER_FILE | awk '{print $3}')
    TEMP_FINAL=$(grep "#define TEMP_FINAL" $HEADER_FILE | awk '{print $3}')
    TEMP_DELTA=$(grep "#define TEMP_DELTA" $HEADER_FILE | awk '{print $3}')
    NPOINTS=$(awk "BEGIN { printf(\"%.0f\", (($TEMP_FINAL - $TEMP_INITIAL) / $TEMP_DELTA) + 1) }")

    # Ejecutar y capturar tiempo
    PERF_OUTPUT=$(perf stat $EXECUTABLE 2>&1)
    TIME=$(echo "$PERF_OUTPUT" | grep "seconds time elapsed" | grep -oP '^\s*\K[\d,]+')
    TIME=${TIME/,/.}

    if [[ -z "$TIME" ]]; then
        OUTPUT="N/A;$COMMENT"
        return
    fi

    # Calcular la métrica
    METRICA=$(awk "BEGIN { printf(\"%.2f\", ($L * $L * $NPOINTS) / $TIME) }")
    OUTPUT="$METRICA;"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Métrica;Comentario"

    #run gcc "-O0" "" "gcc -O0"; echo "$OUTPUT"
    #run gcc-12 "-O0" "" "gcc-12 -O0"; echo "$OUTPUT"
    #run gcc-12 "-O1" "" "gcc-12 -O1"; echo "$OUTPUT"
    #run gcc-12 "-O2" "" "gcc-12 -O2"; echo "$OUTPUT"
    #run gcc-12 "-O3" "" "gcc-12 -O3"; echo "$OUTPUT"
    #run gcc-12 "-Ofast" "" "gcc-12 -Ofast"; echo "$OUTPUT"
    #run gcc-12 "-O0 -march=native" "" "gcc-12 -O0 -march=native"; echo "$OUTPUT"
    #run gcc-12 "-O1 -march=native" "" "gcc-12 -O1 -march=native"; echo "$OUTPUT"
    #run gcc-12 "-O2 -march=native" "" "gcc-12 -O2 -march=native"; echo "$OUTPUT"
    #run gcc-12 "-O3 -march=native" "" "gcc-12 -O3 -march=native"; echo "$OUTPUT"
    #run gcc-12 "-Ofast -march=native" "" "gcc-12 -Ofast -march=native"; echo "$OUTPUT"
    #run gcc-12 "-flto" "-flto" "gcc-12 -flto"; echo "$OUTPUT"
    #run gcc-12 "-floop-block" "" "gcc-12 -floop-block"; echo "$OUTPUT"
    #run gcc-12 "-funroll-loops" "" "gcc-12 -funroll-loops"; echo "$OUTPUT"
    #
    #run clang-15 "-O0" "" "clang-15 -O0"; echo "$OUTPUT"
    #run clang-15 "-O1" "" "clang-15 -O1"; echo "$OUTPUT"
    #run clang-15 "-O2" "" "clang-15 -O2"; echo "$OUTPUT"
    #run clang-15 "-O3" "" "clang-15 -O3"; echo "$OUTPUT"
    #run clang-15 "-Ofast" "" "clang-15 -Ofast"; echo "$OUTPUT"
    #run clang-15 "-O0 -march=native" "" "clang-15 -O0 -march=native"; echo "$OUTPUT"
    #run clang-15 "-O1 -march=native" "" "clang-15 -O1 -march=native"; echo "$OUTPUT"
    #run clang-15 "-O2 -march=native" "" "clang-15 -O2 -march=native"; echo "$OUTPUT"
    #run clang-15 "-O3 -march=native" "" "clang-15 -O3 -march=native"; echo "$OUTPUT"
    #run clang-15 "-Ofast -march=native" "" "clang-15 -Ofast -march=native"; echo "$OUTPUT"
    #run clang-15 "-flto" "-flto" "clang-15 -flto"; echo "$OUTPUT"
    #run clang-15 "-funroll-loops" "" "clang-15 -funroll-loops"; echo "$OUTPUT"

    run icx "-O0" "" "AOCC -O0"; echo "$OUTPUT"
    run icx "-O1" "" "AOCC -O1"; echo "$OUTPUT"
    run icx "-O2" "" "AOCC -O2"; echo "$OUTPUT"
    run icx "-O3" "" "AOCC -O3"; echo "$OUTPUT"
    run icx "-Ofast" "" "AOCC -Ofast"; echo "$OUTPUT"
    run icx "-O0 -march=native" "" "AOCC -O0 -march=native"; echo "$OUTPUT"
    run icx "-O1 -march=native" "" "AOCC -O1 -march=native"; echo "$OUTPUT"
    run icx "-O2 -march=native" "" "AOCC -O2 -march=native"; echo "$OUTPUT"
    run icx "-O3 -march=native" "" "AOCC -O3 -march=native"; echo "$OUTPUT"
    run icx "-Ofast -march=native" "" "AOCC -Ofast -march=native"; echo "$OUTPUT"
    run icx "-flto" "-flto" "AOCC -flto"; echo "$OUTPUT"
    run icx "-funroll-loops" "" "AOCC -funroll-loops"; echo "$OUTPUT"
fi