#!/bin/bash
set -e

export OMP_PROC_BIND=close
source run.sh

echo "Métrica;Comentario"

for THREADS in 1 2 3 4 5 6 7
do
    run icx "-Ofast -flto -march=native -ftree-vectorize -DL=2048 -DSCHEDULE_TYPE=static -fopenmp -DMAX_THREADS=$THREADS" ""; "icx static $THREADS threads"
    echo "$OUTPUT"
    run icx "-Ofast -flto -march=native -ftree-vectorize -DL=2048 -DSCHEDULE_TYPE=dynamic -fopenmp -DMAX_THREADS=$THREADS" ""; "icx dynamic $THREADS threads"
    echo "$OUTPUT"
    run icx "-Ofast -flto -march=native -ftree-vectorize -DL=2048 -DSCHEDULE_TYPE=guided -fopenmp -DMAX_THREADS=$THREADS" ""; "icx guided $THREADS threads"
    echo "$OUTPUT"
    cat /proc/loadavg
done
