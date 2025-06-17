#include <stddef.h>
#include "params.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef DATATYPE elem;

void
update(const float temp,
       elem * grid_r,
       elem * grid_b);
void update_cuda(elem *grid_r, elem *grid_b, float temp);
void cycle_cuda(
    elem *grid_r, elem *grid_b,
    float temp_initial, float temp_final, float temp_delta,
    int tran, int tmax);
void cycle_cuda_with_stats(
    elem *grid_r, elem *grid_b,
    float temp_initial, float temp_final, float temp_delta,
    int tran, int tmax,
    double *temps, double *energies, double *mags, int npoints);
double
calculate(const elem * grid_r,
          const elem * grid_b,
          int * M_max);
// No macro, solo función:
size_t idx(size_t x, size_t y);

#ifdef __cplusplus
}
#endif
