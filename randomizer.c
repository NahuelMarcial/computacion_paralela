#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include "randomizer.h"

static uint64_t semilla;
union rand_num rand_state[MAX_THREADS];

void srand_alt(uint64_t s)
{
	semilla = s-1;
	srand(semilla);
	for (int y=0; y<MAX_THREADS; y++)
		for (int x = 0; x < 4; x++){
			rand_state[y].u64[x] = rand();
		}
}

uint32_t rand_alt(void)
{
	semilla = UINT64_C(6364136223846793005) * semilla
	    + UINT64_C(1442695040888963407);
	return semilla >> 32;
}

void rand_alt_64x4(int tid)
{
	#pragma omp simd
	for(int i =0; i <4; i++)
	{
		rand_state[tid].u64[i] = UINT64_C(6364136223846793005) * rand_state[tid].u64[i]
	    + UINT64_C(1442695040888963407);
	}
}
