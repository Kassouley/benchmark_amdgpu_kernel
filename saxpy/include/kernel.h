#ifndef KERNEL_H
#define KERNEL_H

__global__ void saxpy_kernel(const float a, const float* d_x, float* d_y, const unsigned int size);
void saxpy_cpu(const float a, const float* x, float** y, const unsigned int size);
#endif