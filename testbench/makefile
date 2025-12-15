compile_c:
	riscv32-unknown-elf-gcc -march=rv32im -static testbench_program.c -o testbench_program.elf

compile_asm:
	riscv32-unknown-elf-gcc -march=rv32im -nostdlib -static -nostartfiles -c testbench_program.s -o  testbench_program.elf

mem:
	riscv32-unkown-elf-objcopy testbench_program.elf -O verilog testbench_program.mem

clean:
	rm *.elf, *.mem
	
