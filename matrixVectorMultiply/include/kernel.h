#ifndef KERNEL_H
#define KERNEL_H

__global__ void svmm_kernel (unsigned int N, const float* a, const float* b, float* c);
#endif