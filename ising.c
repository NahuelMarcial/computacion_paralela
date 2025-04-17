#include "ising.h"

#include <math.h>
#include <stdlib.h>
#include <assert.h>
#include "randomizer.h"

#define EXPF_LOOKUP_TABLE_SIZE (16)
typedef enum { RED, BLACK } grid_color;

size_t
idx(size_t x, size_t y) {
	return y * WIDTH + x;
}
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


static
void
update_rb(grid_color color,
          const int * restrict read,
          int * restrict write) {

	int side_shift = color == RED ? -1 : 1;

    uint64_t _rands[(WIDTH+3)/4] = {0};
    uint16_t *rands = (uint16_t *)_rands;

	for (int y = 0; y < HEIGHT; ++y, side_shift = -side_shift) {
        for (int z = 0; z < (WIDTH+3)/4; z++) {
            _rands[z] = rand_alt_64();
        }
        #pragma omp simd
		for (int x = 0; x < WIDTH; ++x) {
			int spin_old = write[idx(x, y)];
			int spin_new = -spin_old;

			// computing h_before
			int spin_neigh_up   = read[idx(x, (y - 1 + HEIGHT) % HEIGHT)];
			int spin_neigh_same = read[idx(x, y)];
			int spin_neigh_side = read[idx((x + side_shift + WIDTH) % WIDTH, y)];
			int spin_neigh_down = read[idx(x, (y + 1) % HEIGHT)];

			int delta_E = 2 * spin_old * (spin_neigh_up + spin_neigh_same + spin_neigh_side + spin_neigh_down);

			float p = (rands[x]) / (float) 0xFFFF;
			// if (delta_E<=0 || p<=expf_lookup.table[delta_E]) {
			// 	write[idx(x, y)] = spin_new;
			// }
            // int update = (delta_E<=0 || p<=expf_lookup.table[delta_E]) &&( spin_new ^ spin_old);
            // write[idx(x, y)] ^= update;
            // int update = (!!(delta_E<=0 || p<=expf_lookup.table[delta_E]))*2 -1;
            // write[idx(x, y)] *= update;

			int pred = (delta_E<=0 || p<=expf_lookup.table[delta_E]);
			write[idx(x, y)] = pred * spin_new + !pred * spin_old;


		}
	}
}

void
update(const float temp,
       int * restrict grid_r,
       int * restrict grid_b) {
    if (expf_lookup.temp != temp) init_expf_lookup_table(temp);
	update_rb(RED, grid_b, grid_r);
	update_rb(BLACK, grid_r, grid_b);
}

static
int
calculate_rb(grid_color color,
             const int * restrict neigh,
             const int * restrict grid,
             int * restrict M_max) {

	int E = 0;
	int side_shift = color == RED ? -1 : 1;

	for (int y = 0; y < HEIGHT; ++y, side_shift = -side_shift) {
        #pragma omp simd
		for (int x = 0; x < WIDTH; ++x) {
			int spin = grid[idx(x, y)];
			int spin_neigh_up   = neigh[idx(x, (y - 1 + HEIGHT) % HEIGHT)];
			int spin_neigh_same = neigh[idx(x, y)];
			int spin_neigh_side = neigh[idx((x + side_shift + WIDTH) % WIDTH, y)];
			int spin_neigh_down = neigh[idx(x, (y + 1) % HEIGHT)];

			E += (spin * spin_neigh_up)   + (spin * spin_neigh_same) +
			     (spin * spin_neigh_side) + (spin * spin_neigh_down);
			*M_max += spin;
		}
	}

	return E;
}

double
calculate(const int * restrict grid_r,
          const int * restrict grid_b,
          int * restrict M_max) {
	int E = 0;
	E += calculate_rb(RED, grid_b, grid_r, M_max);
	E += calculate_rb(BLACK, grid_r, grid_b, M_max);
	return - (double) E / 2.0;
}
