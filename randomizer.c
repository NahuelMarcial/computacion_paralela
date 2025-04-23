#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include "randomizer.h"
static uint64_t semilla;
static uint64_t semillas[4] = {0}; // TODO: Inicializar con algo más interesante


// Implementación de un LCG
void srand_alt(uint64_t s)
{
	semilla = s - 1;
	for (int x = 0; x < 4; x++){
		srand(rand_alt_64());
		semillas[x] = rand() * 0xFFFFFFFFFFFFFFFF;
	}
}

uint32_t rand_alt(void)
{
	semilla = UINT64_C(6364136223846793005) * semilla
	    + UINT64_C(1442695040888963407);
	return semilla >> 32;
}

uint64_t rand_alt_64(void)
{
	semilla = UINT64_C(6364136223846793005) * semilla
	    + UINT64_C(1442695040888963407);
	return semilla;
}

void rand_alt_64x4(uint64_t * ret)
{
	#pragma omp simd
	for(int i =0; i <4; i++)
	{
		semillas[i] = UINT64_C(6364136223846793005) * semillas[i]
	    + UINT64_C(1442695040888963407);
		ret[i] = semillas[i];
	}
}
