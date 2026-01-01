#include <stdio.h>
#include <stdint.h>
#include <time.h>

#define KERNEL_SIDE    3                  // square kernel side, e.g 3 > 3x3= 9 elements
#define WINDOW_SIZE    1000               // up to 4096
#define KERNEL_ELEMS   (KERNEL_SIDE * KERNEL_SIDE)

#define ITERATIONS     WINDOW_SIZE - KERNEL_ELEMS +1
/* -------------------------------------------------
   Software 1D convolution
   ------------------------------------------------- */
uint32_t conv1d_software(
    const uint32_t *kernel,
    const uint32_t *input,
    uint32_t kernel_size,
    uint32_t window_size
)
{
    uint32_t acc = 0;

    // Simple 1D convolution:
    // sum(kernel[i] * input[i]) for valid range
    for (uint32_t i = 0; i < kernel_size && i < window_size; i++) {
        acc += kernel[i] * input[i];
    }

    return acc;
}

/* -------------------------------------------------
   Main
   ------------------------------------------------- */
int main(void)
{
    static uint32_t kernel[KERNEL_ELEMS];
    static uint32_t window[WINDOW_SIZE];
    static uint32_t results[ITERATIONS];

    // Initialize kernel
    for (uint32_t i = 0; i < KERNEL_ELEMS; i++) {
        kernel[i] = i;
    }

    // Initialize input window
    for (uint32_t i = 0; i < WINDOW_SIZE; i++) {
        window[i] = i + 1;
    }

    /* -------------------------------------------------
       Measure software convolution time
       ------------------------------------------------- */
    struct timespec t_start, t_end;

    clock_gettime(CLOCK_MONOTONIC, &t_start);

    for (uint32_t i = 0; i < ITERATIONS; i++) {
        results[i] = conv1d_software(
            kernel,
            window + i,
            KERNEL_ELEMS,
            WINDOW_SIZE
        );
    }

    clock_gettime(CLOCK_MONOTONIC, &t_end);

    /* -------------------------------------------------
       Compute elapsed time
       ------------------------------------------------- */
    int elapsed_nsec =
        (t_end.tv_nsec - t_start.tv_nsec);

    printf("Software convolution benchmark\n");
    printf("Kernel elements : %u\n", KERNEL_ELEMS);
    printf("Window size     : %u\n", WINDOW_SIZE);
    printf("Iterations      : %u\n", ITERATIONS);
    printf("Total time      : %d ns\n", elapsed_nsec);
    printf("Avg per conv    : %.3f ns\n",
           (elapsed_nsec / (double)ITERATIONS));

    // Prevent optimization removal
    printf("Last result     : %u\n", results[ITERATIONS - 1]);

    return 0;
}

