// No stdlib, no includes
typedef unsigned int uint32_t;


static int conv_initialised = 0;
/* -------------------------------------------------
   Configuration (compile-time constants)
   ------------------------------------------------- */
#define KERNEL_SIDE   9                  // square shaped kernel side (e.g 3 means 3x3 kernel)
#define WINDOW_SIZE   1000               // up to 4096
#define KERNEL_ELEMS  (KERNEL_SIDE * KERNEL_SIDE)

/* -------------------------------------------------
   Entry point
   ------------------------------------------------- */
__attribute__((section(".text.entry")))
void _start(void)
{
    extern int main(void);
    main();
}

/* -------------------------------------------------
   Custom convolution function
   ------------------------------------------------- */
uint32_t conv1d(
    uint32_t *kernel,
    uint32_t *input_window,
    uint32_t kernel_size,
    uint32_t window_size
)
{
    uint32_t result;
    
    if (!conv_initialised){ 
    	asm volatile (
        	"convsetbase %1, %2\n" //%1:kernel base, %2; window base
        	"convsetsize %3, %4\n" //%3:window size, %4: kernel size
        	"convrun     %0\n"
        	: "=r"(result)
        	: "r"(kernel),
          	"r"(input_window),
          	"r"(window_size),
          	"r"(kernel_size)
        	: "memory"
    	);
	conv_initialised = 1;
    } else {
	    asm volatile (
		"convrun     %0\n" : "=r"(result)
		);
    }

    return result;
}

/* -------------------------------------------------
   Main
   ------------------------------------------------- */
int main(void)
{
    // Static buffers (no heap)
    static uint32_t kernel[KERNEL_ELEMS];
    static uint32_t window[WINDOW_SIZE];

    // Fill kernel
    for (uint32_t i = 0; i < KERNEL_ELEMS; i++) {
        kernel[i] = i;
    }

    asm volatile ( "nop\n");
    // Fill input window
    for (uint32_t i = 0; i < WINDOW_SIZE; i++) {
        window[i] = i + 1;
    }

    for(uint32_t i = 0; i <= (WINDOW_SIZE - KERNEL_ELEMS); i++){
	uint32_t result = conv1d(
        	kernel,
        	window,
        	KERNEL_SIDE,
        	WINDOW_SIZE
    	);
    }
}


