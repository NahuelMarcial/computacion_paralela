#include<inttypes.h>
#include "randomizer.h"
static uint64_t semilla;

// Implementación de un LCG
void srand_alt(uint64_t s)
{
	semilla = s - 1;
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
