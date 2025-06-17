# Compiladores
NVCC ?= nvcc

# Flags
NVCCFLAGS := -O3 -arch=sm_61 -Xcompiler -fopenmp -std=c++11
LDFLAGS := -lm
GL_LDFLAGS := -lGL -lglfw

# Archivos
TARGETS = tiny_ising_cuda demo_cuda

all: $(TARGETS)

tiny_ising_cuda: tiny_ising.c ising.cpp ising_cuda.cu wtime.c randomizer.c
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(LDFLAGS)

demo_cuda: demo.c ising.cpp ising_cuda.cu wtime.c randomizer.c
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(LDFLAGS) $(GL_LDFLAGS)

clean:
	rm -f $(TARGETS) *.o

.PHONY: clean all
