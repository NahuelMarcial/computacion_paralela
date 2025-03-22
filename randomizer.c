#include "randomizer.h"

static unsigned int current_seed;

void init_randomizer(unsigned int seed) {
    current_seed = seed;
}

float generate_random() {
    // Generador Congruencial Lineal (LCG)
    current_seed = (1664525 * current_seed + 1013904223) % 0xFFFFFFFF;
    return current_seed / (float)0xFFFFFFFF;
}
