#!/bin/bash
set -e

export OMP_PROC_BIND=close
source run.sh

SCHEDULER_TYPE="static" # Cambia si deseas otro scheduler

echo "Métrica;Comentario"

for THREADS in 1 2 4 6 8 10 12 14 16
do
    for PADDING in 1 0
    do
        run icx "-Ofast -flto -march=native -ftree-vectorize -DL=2048 -DSCHEDULE_TYPE=$SCHEDULER_TYPE -fopenmp -DMAX_THREADS=$THREADS -DPADDING=$PADDING" ""; "icx PADDING=$PADDING $SCHEDULER_TYPE $THREADS threads"
        echo "$OUTPUT"
        cat /proc/loadavg
    done
done
