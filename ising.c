#include "ising.h"
#include "randomizer.h"

#include <math.h>
#include <stdlib.h>

static struct {
    float temp;
    float table[5]; // EXPF_LOOKUP_TABLE_SIZE = 5 (for half_delta_E from 0 to 4)
} expf_lookup = {0.0, {0.0}};

static void init_expf_lookup_table(const float temp)
{
    expf_lookup.temp = temp;
    for (int half_delta_E = 1; half_delta_E <= 4; ++half_delta_E) {
        expf_lookup.table[half_delta_E] = expf(-(half_delta_E * 2) / temp);
    }
}

void update(const float temp, int grid[L][L])
{
    // typewriter update
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

            if (delta_E <= 0 || p <= expf_lookup.table[half_delta_E]) {
                write[idx(x,y)] = spin_new;
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
