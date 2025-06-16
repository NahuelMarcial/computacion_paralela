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
double
calculate(const elem * grid_r,
          const elem * grid_b,
          int * M_max);
// No macro, solo función:
size_t idx(size_t x, size_t y);

#ifdef __cplusplus
}
#endif
