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

__global__ void cycle_kernel(
    elem *grid_r, elem *grid_b,
    float temp_initial, float temp_final, float temp_delta,
    int tran, int tmax, int npoints, int width, int height,
    curandState *states, float *temps)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) return;

    int tid = y * width + x;
    curandState localState = states[tid];

    for (int t_idx = 0; t_idx < npoints; ++t_idx) {
        float temp = temp_initial + t_idx * temp_delta;
        // Precalcula tabla de lookup para esta temperatura (en registros)
        float expf_lookup[EXPF_LOOKUP_TABLE_SIZE];
        for (int half_delta_E = 0; half_delta_E < EXPF_LOOKUP_TABLE_SIZE; ++half_delta_E) {
            if (half_delta_E >= 1 && half_delta_E <= 4)
                expf_lookup[half_delta_E] = expf(-(half_delta_E * 2) / temp) * 0xFFFF;
            else
                expf_lookup[half_delta_E] = 0.0f;
        }

        // Equilibración
        for (int j = 0; j < tran; ++j) {
            // RED
            int color = RED;
            int side_shift = (color == RED ? -1 : 1) * ((y % 2) ? -1 : 1);
            elem spin_old = grid_r[y * width + x];
            elem spin_up    = grid_b[((y - 1 + height) % height) * width + x];
            elem spin_same  = grid_b[y * width + x];
            elem spin_side  = grid_b[y * width + ((x + side_shift + width) % width)];
            elem spin_down  = grid_b[((y + 1) % height) * width + x];
            int half_delta_E = spin_old * (spin_up + spin_same + spin_side + spin_down);
            float r = curand_uniform(&localState) * 0xFFFF;
            int update = (half_delta_E <= 0 || r <= expf_lookup[half_delta_E]) ? -1 : 1;
            grid_r[y * width + x] = spin_old * update;
            __syncthreads();

            // BLACK
            color = BLACK;
            side_shift = (color == RED ? -1 : 1) * ((y % 2) ? -1 : 1);
            spin_old = grid_b[y * width + x];
            spin_up    = grid_r[((y - 1 + height) % height) * width + x];
            spin_same  = grid_r[y * width + x];
            spin_side  = grid_r[y * width + ((x + side_shift + width) % width)];
            spin_down  = grid_r[((y + 1) % height) * width + x];
            half_delta_E = spin_old * (spin_up + spin_same + spin_side + spin_down);
            r = curand_uniform(&localState) * 0xFFFF;
            update = (half_delta_E <= 0 || r <= expf_lookup[half_delta_E]) ? -1 : 1;
            grid_b[y * width + x] = spin_old * update;
            __syncthreads();
        }
        // Aquí podrías calcular energía/magnetización en GPU y guardarla en un array si quieres
    }
    states[tid] = localState;
}

// Kernel para calcular energía y magnetización por bloque (sin atomicAdd para double)
__global__ void measure_kernel(
    const elem *grid_r, const elem *grid_b,
    int width, int height,
    double *energy_blocks, double *mag_blocks)
{
    __shared__ double E_block[BLOCK_SIZE * BLOCK_SIZE];
    __shared__ double M_block[BLOCK_SIZE * BLOCK_SIZE];

    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    int tid = threadIdx.y * blockDim.x + threadIdx.x;

    double E = 0.0, M = 0.0;
    if (x < width && y < height) {
        elem spin = grid_r[y * width + x];
        elem spin_b = grid_b[y * width + x];
        elem up    = grid_b[((y - 1 + height) % height) * width + x];
        elem same  = grid_b[y * width + x];
        elem side  = grid_b[y * width + ((x + 1) % width)];
        elem down  = grid_b[((y + 1) % height) * width + x];
        E = -spin * (up + same + side + down);
        M = spin + spin_b;
    }
    E_block[tid] = E;
    M_block[tid] = M;
    __syncthreads();

    // Reducción en bloque
    for (int s = blockDim.x * blockDim.y / 2; s > 0; s >>= 1) {
        if (tid < s) {
            E_block[tid] += E_block[tid + s];
            M_block[tid] += M_block[tid + s];
        }
        __syncthreads();
    }

    // Escribir resultado parcial por bloque
    if (tid == 0) {
        int blockId = blockIdx.y * gridDim.x + blockIdx.x;
        energy_blocks[blockId] = E_block[0];
        mag_blocks[blockId] = M_block[0];
    }
}

// Modifica cycle_cuda para medir en GPU y copiar a CPU
void cycle_cuda_with_stats(
    elem *grid_r, elem *grid_b,
    float temp_initial, float temp_final, float temp_delta,
    int tran, int tmax,
    double *temps, double *energies, double *mags, int npoints)
{
    size_t size = WIDTH * HEIGHT * sizeof(elem);

    elem *d_grid_r, *d_grid_b;
    cudaMalloc(&d_grid_r, size);
    cudaMalloc(&d_grid_b, size);

    cudaMemcpy(d_grid_r, grid_r, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_grid_b, grid_b, size, cudaMemcpyHostToDevice);

    static bool initialized = false;
    static curandState *d_states = NULL;
    if (!initialized) {
        cudaMalloc(&d_states, WIDTH * HEIGHT * sizeof(curandState));
        dim3 grid_rng((WIDTH * HEIGHT + 255) / 256);
        init_curand_states<<<grid_rng, 256>>>(d_states, time(NULL));
        cudaDeviceSynchronize();
        initialized = true;
    }

    dim3 blockDim(BLOCK_SIZE, BLOCK_SIZE);
    dim3 gridDim((WIDTH + BLOCK_SIZE - 1) / BLOCK_SIZE,
                 (HEIGHT + BLOCK_SIZE - 1) / BLOCK_SIZE);
    int numBlocks = gridDim.x * gridDim.y;

    double *d_Eblocks, *d_Mblocks;
    double *h_Eblocks = (double*)malloc(numBlocks * sizeof(double));
    double *h_Mblocks = (double*)malloc(numBlocks * sizeof(double));
    cudaMalloc(&d_Eblocks, numBlocks * sizeof(double));
    cudaMalloc(&d_Mblocks, numBlocks * sizeof(double));

    for (int t_idx = 0; t_idx < npoints; ++t_idx) {
        float temp = temp_initial + t_idx * temp_delta;
        // Equilibración
        for (int j = 0; j < tran; ++j) {
            init_expf_lookup_table_cuda(temp);
            update_kernel<<<gridDim, blockDim>>>(RED, d_grid_b, d_grid_r, WIDTH, HEIGHT, d_states);
            cudaDeviceSynchronize();
            update_kernel<<<gridDim, blockDim>>>(BLACK, d_grid_r, d_grid_b, WIDTH, HEIGHT, d_states);
            cudaDeviceSynchronize();
        }

        double E_sum = 0.0, M_sum = 0.0;
        for (int j = 0; j < tmax; ++j) {
            init_expf_lookup_table_cuda(temp);
            update_kernel<<<gridDim, blockDim>>>(RED, d_grid_b, d_grid_r, WIDTH, HEIGHT, d_states);
            cudaDeviceSynchronize();
            update_kernel<<<gridDim, blockDim>>>(BLACK, d_grid_r, d_grid_b, WIDTH, HEIGHT, d_states);
            cudaDeviceSynchronize();

            // Medir en GPU (reducción por bloques)
            cudaMemset(d_Eblocks, 0, numBlocks * sizeof(double));
            cudaMemset(d_Mblocks, 0, numBlocks * sizeof(double));
            measure_kernel<<<gridDim, blockDim>>>(d_grid_r, d_grid_b, WIDTH, HEIGHT, d_Eblocks, d_Mblocks);
            cudaDeviceSynchronize();
            cudaMemcpy(h_Eblocks, d_Eblocks, numBlocks * sizeof(double), cudaMemcpyDeviceToHost);
            cudaMemcpy(h_Mblocks, d_Mblocks, numBlocks * sizeof(double), cudaMemcpyDeviceToHost);
            double E = 0.0, M = 0.0;
            for (int b = 0; b < numBlocks; ++b) {
                E += h_Eblocks[b];
                M += h_Mblocks[b];
            }
            E_sum += E;
            M_sum += fabs(M) / (double)(WIDTH * HEIGHT);
        }
        temps[t_idx] = temp;
        energies[t_idx] = E_sum / tmax;
        mags[t_idx] = M_sum / tmax;
    }

    cudaMemcpy(grid_r, d_grid_r, size, cudaMemcpyDeviceToHost);
    cudaMemcpy(grid_b, d_grid_b, size, cudaMemcpyDeviceToHost);

    cudaFree(d_grid_r);
    cudaFree(d_grid_b);
    cudaFree(d_Eblocks);
    cudaFree(d_Mblocks);
    free(h_Eblocks);
    free(h_Mblocks);
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

void cycle_cuda(
    elem *grid_r, elem *grid_b,
    float temp_initial, float temp_final, float temp_delta,
    int tran, int tmax)
{
    size_t size = WIDTH * HEIGHT * sizeof(elem);

    elem *d_grid_r, *d_grid_b;
    cudaMalloc(&d_grid_r, size);
    cudaMalloc(&d_grid_b, size);

    cudaMemcpy(d_grid_r, grid_r, size, cudaMemcpyHostToDevice);
    cudaMemcpy(d_grid_b, grid_b, size, cudaMemcpyHostToDevice);

    static bool initialized = false;
    static curandState *d_states = NULL;
    if (!initialized) {
        cudaMalloc(&d_states, WIDTH * HEIGHT * sizeof(curandState));
        dim3 grid_rng((WIDTH * HEIGHT + 255) / 256);
        init_curand_states<<<grid_rng, 256>>>(d_states, time(NULL));
        cudaDeviceSynchronize();
        initialized = true;
    }

    int npoints = (int)((temp_final - temp_initial) / temp_delta + 1.5);

    dim3 blockDim(BLOCK_SIZE, BLOCK_SIZE);
    dim3 gridDim((WIDTH + BLOCK_SIZE - 1) / BLOCK_SIZE,
                 (HEIGHT + BLOCK_SIZE - 1) / BLOCK_SIZE);

    cycle_kernel<<<gridDim, blockDim>>>(
        d_grid_r, d_grid_b,
        temp_initial, temp_final, temp_delta,
        tran, tmax, npoints, WIDTH, HEIGHT, d_states, NULL);
    cudaDeviceSynchronize();

    cudaMemcpy(grid_r, d_grid_r, size, cudaMemcpyDeviceToHost);
    cudaMemcpy(grid_b, d_grid_b, size, cudaMemcpyDeviceToHost);

    cudaFree(d_grid_r);
    cudaFree(d_grid_b);
}
