CC?=gcc
CFLAGS:=-std=c11 -Wall -Wextra -fopenmp $(CFLAGS)
LDFLAGS:=-lm -fopenmp $(LDFLAGS)
GL_LDFLAGS=-lGL -lglfw

# Files
TARGETS=tiny_ising demo

# Rules
all: clean $(TARGETS)

tiny_ising: tiny_ising.o ising.o wtime.o randomizer.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

demo: demo.o ising.o wtime.o randomizer.o
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) $(GL_LDFLAGS)

clean:
	rm -f $(TARGETS) *.o

.PHONY: clean all

