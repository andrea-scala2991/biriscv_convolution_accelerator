.text

_start:
        li x1, 100

        li x2, 42

        sw x2, 0(x1)

        lw x3, 0(x1)

        add x4, x3, x2

        mul x5, x4, x3

        div x6, x5, x2

        sll x7, x6, x2

        bne x7, x6, done

done:
        nop

