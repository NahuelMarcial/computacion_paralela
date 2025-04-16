#include "ising.h"
#include "randomizer.h"

#include <math.h>
#include <stdlib.h>
#include <assert.h>

#define EXPF_LOOKUP_TABLE_SIZE (16)
static struct {
    float temp;
    float table[EXPF_LOOKUP_TABLE_SIZE];
} expf_lookup = {0.0, {0.0}};

static void init_expf_lookup_table(const float temp)
{
    expf_lookup.temp = temp;
    for (int delta_E = 1; delta_E <= 8; ++delta_E) {
        expf_lookup.table[delta_E] = expf(-delta_E / temp);
    }
}

void update(const float temp, int grid[L][L])
{
    // typewriter update
    if (expf_lookup.temp != temp) init_expf_lookup_table(temp);

    for (unsigned int i = 0; i < L; ++i) {
        for (unsigned int j = 0; j < L; ++j) {
            int spin_old = grid[i][j];
            int spin_new = (-1) * spin_old;

            int spin_neigh_n = grid[(i + L - 1) % L][j];
            int spin_neigh_e = grid[i][(j + 1) % L];
            int spin_neigh_w = grid[i][(j + L - 1) % L];
            int spin_neigh_s = grid[(i + 1) % L][j];

            int delta_E = 2 * spin_old * (spin_neigh_n + spin_neigh_e + spin_neigh_w + spin_neigh_s);
            float p = generate_random();

            assert(expf_lookup.temp == temp);
            assert(delta_E <= 0 || fabsf(expf(-delta_E / temp) - expf_lookup.table[delta_E]) < 0.0001);

            if (delta_E <= 0 || p <= expf_lookup.table[delta_E]) {
                grid[i][j] = spin_new;
            }
        }
    }
}

double calculate(int grid[L][L], int* M_max)
{
    int E = 0;
    for (unsigned int i = 0; i < L; ++i) {
        
        for (unsigned int j = i%2; j < L; j+=2) {
            int spin = grid[i][j];
            int spin_neigh_n = grid[(i + 1) % L][j];
            int spin_neigh_e = grid[i][(j + 1) % L];
            int spin_neigh_w = grid[i][(j + L - 1) % L];
            int spin_neigh_s = grid[(i + L - 1) % L][j];

            E += (spin * spin_neigh_n) + (spin * spin_neigh_e) + (spin * spin_neigh_w) + (spin * spin_neigh_s);
            *M_max += spin;
        }
    }
    return -((double)E);
    
}
