#include<inttypes.h>
#include "params.h"

#define RAND_MAX_ALT 0xFFFFFFFF

union rand_num {
	uint64_t u64[4<<PADDING];
	uint16_t u16[16<<PADDING];
};

extern union rand_num rand_state[MAX_THREADS];

void srand_alt(uint64_t s);
uint32_t rand_alt(void);
void rand_alt_64x4(int tid);
