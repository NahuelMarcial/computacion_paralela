#include<inttypes.h>

#define RAND_MAX_ALT 0xFFFFFFFF
void srand_alt(uint64_t s);

uint32_t rand_alt(void);
uint64_t rand_alt_64(void);
void rand_alt_64x4(uint64_t * ret);
