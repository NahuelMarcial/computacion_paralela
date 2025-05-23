#include "ising.h"

#include <math.h>
#include <stdlib.h>
#include <assert.h>
#include <omp.h>

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
    for (int half_delta_E = 1; half_delta_E <= 4; ++half_delta_E) {
        expf_lookup.table[half_delta_E] = expf(-(half_delta_E*2) / temp) * (float)0xFFFF;
    }
}

static
void
update_rb(grid_color color,
          const elem * restrict read,
          elem * restrict write) {

	int initial_side_shift = color == RED ? -1 : 1;

	static_assert(WIDTH % 16 == 0, "WIDTH must be a multiple of 16");

	#pragma omp parallel for num_threads(MAX_THREADS) default(none) shared(read,write,initial_side_shift,expf_lookup,rand_state) schedule(SCHEDULE_TYPE)
	for (int y = 0; y < HEIGHT; ++y) {
		int tid = omp_get_thread_num();
		int side_shift = initial_side_shift * ((y%2)?-1:1);
		for (int _x = 0; _x < WIDTH; _x+=16) {
			rand_alt_64x4(tid);
			#pragma omp simd
			for (int i = 0; i<16; i++) {
				int x = _x+i;
				elem spin_old = write[idx(x, y)];
				elem spin_neigh_up   = read[idx(x, (y - 1 + HEIGHT) % HEIGHT)];
				elem spin_neigh_same = read[idx(x, y)];
				elem spin_neigh_side = read[idx((x + side_shift + WIDTH) % WIDTH, y)];
				elem spin_neigh_down = read[idx(x, (y + 1) % HEIGHT)];

				elem half_delta_E = spin_old * (spin_neigh_up + spin_neigh_same + spin_neigh_side + spin_neigh_down);

				float p = (rand_state[tid].u16[i]);
				elem update = ((half_delta_E<=0 || p<=expf_lookup.table[half_delta_E]))*-2 +1;
				write[idx(x, y)] *= update;
			}
		}
	}
}

void
update(const float temp,
       elem * restrict grid_r,
       elem * restrict grid_b) {
    if (expf_lookup.temp != temp) init_expf_lookup_table(temp);
	update_rb(RED, grid_b, grid_r);
	update_rb(BLACK, grid_r, grid_b);
}

static
int
calculate_rb(grid_color color,
             const elem * restrict neigh,
             const elem * restrict grid,
             int * restrict M_max) {

	int E = 0, M = 0;
	int initial_side_shift = color == RED ? -1 : 1;

	#pragma omp parallel for num_threads(MAX_THREADS) default(none) shared(neigh,grid,initial_side_shift) reduction(+:E,M)
	for (int y = 0; y < HEIGHT; ++y) {
		int side_shift = initial_side_shift * ((y%2)?-1:1);
        #pragma omp simd
		for (int x = 0; x < WIDTH; ++x) {
			elem spin = grid[idx(x, y)];
			elem spin_neigh_up   = neigh[idx(x, (y - 1 + HEIGHT) % HEIGHT)];
			elem spin_neigh_same = neigh[idx(x, y)];
			elem spin_neigh_side = neigh[idx((x + side_shift + WIDTH) % WIDTH, y)];
			elem spin_neigh_down = neigh[idx(x, (y + 1) % HEIGHT)];

			E += spin * (spin_neigh_up + spin_neigh_same +
			     spin_neigh_side + spin_neigh_down);
			M += spin + spin_neigh_same;
		}
	}

	*M_max += M;
	return E;
}

double
calculate(const elem * restrict grid_r,
          const elem * restrict grid_b,
          int * restrict M_max) {
	int E = 0;
	E += calculate_rb(RED, grid_b, grid_r, M_max);
	return - (double) E;
}
