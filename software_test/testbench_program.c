#include <stdint.h>

int main(void)
{
    asm volatile (
        /* _start: */
        "li x1, 100\n\t"

        "li x2, 42\n\t"

        "sw x2, 0(x1)\n\t"

        "lw x3, 0(x1)\n\t"

        "add x4, x3, x2\n\t"

	"mul x5, x4, x3\n\t"

        "div x6, x5, x2\n\t"

	"sll x7, x6, x2\n\t"

	"bne x7, x6, done\n\t"

	"done:\n\t"

	"nop\n\t"
    );
    return 0;
}

