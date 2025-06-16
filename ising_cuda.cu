#include <cuda_runtime.h>
#include <curand_kernel.h>
#include "ising.h"
#define __CUDA_NO_HALF_OPERATORS__

#define BLOCK_SIZE 16
#define EXPF_LOOKUP_TABLE_SIZE 16

typedef enum { RED, BLACK } grid_color;

// Lookup de expf precalculado (en host y enviado a device)
__device__ float d_expf_lookup[EXPF_LOOKUP_TABLE_SIZE];
static float h_expf_lookup[EXPF_LOOKUP_TABLE_SIZE];

// Inicialización en host
void init_expf_lookup_table_cuda(float temp) {
    for (int half_delta_E = 1; half_delta_E <= 4; ++half_delta_E) {
        h_expf_lookup[half_delta_E] = expf(-(half_delta_E * 2) / temp) * 0xFFFF;
    }
    cudaMemcpyToSymbol(d_expf_lookup, h_expf_lookup, sizeof(h_expf_lookup));
}

// Inicialización de RNG por hilo
__global__ void init_curand_states(curandState *states, unsigned long seed) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    curand_init(seed, tid, 0, &states[tid]);
}

__device__ inline size_t idx(size_t x, size_t y, size_t width) {
    return y * width + x;
}

__global__ void update_kernel(
    grid_color color, const elem *read, elem *write,
    int width, int height, curandState *states)
{
    // Coordenadas globales
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    // Coordenadas locales en el bloque
    int lx = threadIdx.x + 1;
    int ly = threadIdx.y + 1;

    // Shared memory tile con halo
    __shared__ elem tile[BLOCK_SIZE + 2][BLOCK_SIZE + 2];

    // Cargar el dato propio
    if (x < width && y < height)
        tile[ly][lx] = read[idx(x, y, width)];
    // Halo izquierdo
    if (threadIdx.x == 0)
        tile[ly][0] = read[idx((x - 1 + width) % width, y, width)];
    // Halo derecho
    if (threadIdx.x == BLOCK_SIZE - 1 || x == width - 1)
        tile[ly][BLOCK_SIZE + 1] = read[idx((x + 1) % width, y, width)];
    // Halo arriba
    if (threadIdx.y == 0)
        tile[0][lx] = read[idx(x, (y - 1 + height) % height, width)];
    // Halo abajo
    if (threadIdx.y == BLOCK_SIZE - 1 || y == height - 1)
        tile[BLOCK_SIZE + 1][lx] = read[idx(x, (y + 1) % height, width)];
    // Esquinas (opcional, solo si accedes)
    if (threadIdx.x == 0 && threadIdx.y == 0)
        tile[0][0] = read[idx((x - 1 + width) % width, (y - 1 + height) % height, width)];
    if (threadIdx.x == 0 && (threadIdx.y == BLOCK_SIZE - 1 || y == height - 1))
        tile[BLOCK_SIZE + 1][0] = read[idx((x - 1 + width) % width, (y + 1) % height, width)];
    if ((threadIdx.x == BLOCK_SIZE - 1 || x == width - 1) && threadIdx.y == 0)
        tile[0][BLOCK_SIZE + 1] = read[idx((x + 1) % width, (y - 1 + height) % height, width)];
    if ((threadIdx.x == BLOCK_SIZE - 1 || x == width - 1) && (threadIdx.y == BLOCK_SIZE - 1 || y == height - 1))
        tile[BLOCK_SIZE + 1][BLOCK_SIZE + 1] = read[idx((x + 1) % width, (y + 1) % height, width)];
    __syncthreads();

    if (x >= width || y >= height) return;

    int tid = threadIdx.y * blockDim.x + threadIdx.x + blockIdx.y * gridDim.x * blockDim.x + blockIdx.x * blockDim.x;
    curandState localState = states[tid];

    int side_shift = (color == RED ? -1 : 1) * ((y % 2) ? -1 : 1);

    // Usar shared memory para vecinos
    elem spin_old = tile[ly][lx];
    elem spin_up    = tile[ly - 1][lx];
    elem spin_same  = tile[ly][lx];
    elem spin_side  = tile[ly][lx + side_shift];
    elem spin_down  = tile[ly + 1][lx];

    int half_delta_E = spin_old * (spin_up + spin_same + spin_side + spin_down);

    float r = curand_uniform(&localState) * 0xFFFF;
    int update = (half_delta_E <= 0 || r <= d_expf_lookup[half_delta_E]) ? -1 : 1;

    write[idx(x, y, width)] = spin_old * update;
    states[tid] = localState;
}

void update_cuda(elem *grid_r, elem *grid_b, float temp) {
    static bool initialized = false;
    static curandState *d_states = NULL;

    size_t size = WIDTH * HEIGHT * sizeof(elem);

    // Allocar memoria en device
    elem *d_read, *d_write;
    cudaMalloc(&d_read, size);
    cudaMalloc(&d_write, size);

    // RNG states
    if (!initialized) {
        cudaMalloc(&d_states, WIDTH * HEIGHT * sizeof(curandState));
        dim3 grid_rng((WIDTH * HEIGHT + 255) / 256);
        init_curand_states<<<grid_rng, 256>>>(d_states, time(NULL));
        initialized = true;
    }

    // Init tabla exp
    init_expf_lookup_table_cuda(temp);

    // Copy datos de host a device
    cudaMemcpy(d_read, grid_b, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_write, grid_r, size, cudaMemcpyHostToDevice);

    dim3 blockDim(BLOCK_SIZE, BLOCK_SIZE);
    dim3 gridDim((WIDTH + BLOCK_SIZE - 1) / BLOCK_SIZE,
                 (HEIGHT + BLOCK_SIZE - 1) / BLOCK_SIZE);

    // RED
    update_kernel<<<gridDim, blockDim>>>(RED, d_read, d_write, WIDTH, HEIGHT, d_states);
    cudaDeviceSynchronize();

    // BLACK
    update_kernel<<<gridDim, blockDim>>>(BLACK, d_write, d_read, WIDTH, HEIGHT, d_states);
    cudaDeviceSynchronize();

    // Copy back
    cudaMemcpy(grid_r, d_write, size, cudaMemcpyDeviceToHost);
    cudaMemcpy(grid_b, d_read, size, cudaMemcpyDeviceToHost);

    // Free
    cudaFree(d_read);
    cudaFree(d_write);
}
