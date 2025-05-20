#!/bin/bash
set -e

export OMP_PROC_BIND=close
source run.sh

SCHEDULER_TYPE="static" # Cambia esto si quieres otro scheduler
THREADS=4               # Cambia esto por la cantidad de threads deseada

echo "Métrica;Comentario"

for L in 128 256 384 512 768 1024 1536 2048 4096
do
    run icx "-Ofast -flto -march=native -ftree-vectorize -DL=$L -DSCHEDULE_TYPE=$SCHEDULER_TYPE -fopenmp -DMAX_THREADS=$THREADS" ""; "icx L=$L $SCHEDULER_TYPE $THREADS threads"
    echo "$OUTPUT"
    cat /proc/loadavg
done
