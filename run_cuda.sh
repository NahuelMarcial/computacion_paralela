#!/bin/bash

set -e

# Variables
EXE=tiny_ising_cuda

# Compilar: asume que tienes ising_cuda.cu y Makefile preparado para CUDA
nvcc -O3 -DUSE_CUDA -Xcompiler -fopenmp -o $EXE tiny_ising.c ising.c ising_cuda.cu randomizer.c -lm

# Ejecutar y mostrar estadísticas en pantalla
./$EXE

echo "Ejecución CUDA finalizada."
