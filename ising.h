#include <stddef.h>
#include "params.h"

typedef DATATYPE elem;

void
update(const float temp,
       elem * restrict grid_r,
       elem * restrict grid_b);
double
calculate(const elem * restrict grid_r,
          const elem * restrict grid_b,
          int * restrict M_max);
size_t
idx(size_t x, size_t y);
