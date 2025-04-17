/*
 * Tiny Ising model.
 * Loosely based on  "q-state Potts model metastability
 * study using optimized GPU-based Monte Carlo algorithms",
 * Ezequiel E. Ferrero, Juan Pablo De Francesco, Nicolás Wolovick,
 * Sergio A. Cannas
 * http://arxiv.org/abs/1101.0876
 *
 * Debugging: Ezequiel Ferrero
 */

#include "colormap.h"
#include "gl2d.h"
#include "ising.h"
#include "params.h"
#include "wtime.h"

#include <assert.h>
#include <limits.h> // UINT_MAX
#include <stdio.h> // printf()
#include <stdlib.h> // rand()
#include <string.h>
#include <time.h> // time()
#include "randomizer.h"

#define MAXFPS 60
#define N (L * L) // system size
#define SEED (time(NULL)) // random seed


/**
 * GL output
 */
static void draw(gl2d_t gl2d, float t_now, float t_min, float t_max, int * restrict grid_r,  int * restrict grid_b)
{
    static double last_frame = 0.0;

    double current_time = wtime();
    if (current_time - last_frame < 1.0 / MAXFPS) {
        return;
    }
    last_frame = current_time;

    float row[L * 3];
    float color[3] = {0.5};
    colormap_rgbf(COLORMAP_VIRIDIS, t_now, t_min, t_max, &color[0], &color[1], &color[2]);
    for (unsigned int y = 0; y < HEIGHT; ++y) {
        memset(row, 0, sizeof(row));
        int * grid_left = ((y&1)?grid_r:grid_b), * grid_right = ((y&1)?grid_b:grid_r);
        for (unsigned int x = 0; x < WIDTH; ++x) {
            if ( grid_left[idx(x, y)] > 0) {
                row[x*2 * 3] = color[0];
                row[x*2 * 3 + 1] = color[1];
                row[x*2 * 3 + 2] = color[2];
            }
            if ( grid_right[idx(x, y)] > 0) {
                row[(x*2+1) * 3] = color[0];
                row[(x*2+1) * 3 + 1] = color[1];
                row[(x*2+1) * 3 + 2] = color[2];
            }
        }
        gl2d_draw_rgbf(gl2d, 0, y, L, 1, row);
    }
    gl2d_display(gl2d);
}


static void cycle(gl2d_t gl2d, const double initial, const double final, const double step, int * restrict grid_r,  int * restrict grid_b)
{
    assert((0 < step && initial <= final) || (step < 0 && final <= initial));
    int modifier = (0 < step) ? 1 : -1;

    for (double temp = initial; modifier * temp <= modifier * final; temp += step) {
        printf("Temp: %f\n", temp);
        for (unsigned int j = 0; j < TRAN + TMAX; ++j) {
            update(temp, grid_r, grid_b);
            draw(gl2d, temp, initial < final ? initial : final, initial < final ? final : initial, grid_r, grid_b);
        }
    }
}


static void init(
       int * restrict grid_r,
       int * restrict grid_b)
{
    for (unsigned int y = 0; y < HEIGHT; ++y) {
        for (unsigned int x = 0; x < WIDTH; ++x) {
            grid_r[idx(x, y)] = (rand_alt() / (float)RAND_MAX_ALT) < 0.5f ? -1 : 1;
            grid_b[idx(x, y)] = (rand_alt() / (float)RAND_MAX_ALT) < 0.5f ? -1 : 1;
        }
    }
}


int main(void)
{
    // parameter checking
#if (defined(__GNUC__) && !defined(__clang__)) && !defined(__INTEL_COMPILER)
    static_assert(TEMP_DELTA != 0, "Invalid temperature step");
    static_assert(((TEMP_DELTA > 0) && (TEMP_INITIAL <= TEMP_FINAL)) || ((TEMP_DELTA < 0) && (TEMP_INITIAL >= TEMP_FINAL)), "Invalid temperature range+step");
#endif // expression in static assertion should be an integer constant expression (but GCC doesn't complain)
    static_assert(TRAN + TMAX > 0, "Invalid times");
    static_assert((L * L / 2) * 4ULL < UINT_MAX, "L too large for uint indices"); // max energy, that is all spins are the same, fits into a ulong

    // print header
    printf("# L: %i\n", L);
    printf("# Minimum Temperature: %f\n", TEMP_INITIAL);
    printf("# Maximum Temperature: %f\n", TEMP_FINAL);
    printf("# Temperature Step: %.12f\n", TEMP_DELTA);
    printf("# Equilibration Time: %i\n", TRAN);
    printf("# Measurement Time: %i\n", TMAX);

    // configure RNG
    srand_alt(SEED);

    gl2d_t gl2d = gl2d_init("tiny_ising", L, L);

    // start timer
    double start = wtime();

    // clear the grid_r, grid_b
    size_t size = HEIGHT * WIDTH * sizeof(int);
    int * grid_r = malloc(size);
    int * grid_b = malloc(size);
    init(grid_r, grid_b);

    // temperature increasing cycle
    cycle(gl2d, TEMP_INITIAL, TEMP_FINAL, TEMP_DELTA, grid_r, grid_b);

    // stop timer
    double elapsed = wtime() - start;
    printf("# Total Simulation Time (sec): %lf\n", elapsed);

    gl2d_destroy(gl2d);

    return 0;
}
