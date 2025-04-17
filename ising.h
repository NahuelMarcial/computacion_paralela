#include <stddef.h>
#include "params.h"

void
update(const float temp,
       int * restrict grid_r,
       int * restrict grid_b);
double
calculate(const int * restrict grid_r,
          const int * restrict grid_b,
          int * restrict M_max);
size_t
idx(size_t x, size_t y);
