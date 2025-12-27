all: compile_c compile_c_riscv compile_asm mem

compile_c:
	gcc -O0 main.c -o main.exe

compile_c_riscv:
	riscv32-unknown-elf-gcc -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -ffreestanding -Wl,-T,link.ld -Wl,-Map=output.map -o main_riscv.elf main_riscv.c

compile_asm:
	riscv32-unknown-elf-as -march=rv32im test_conv.s -o  test_conv.elf

mem:
	riscv32-unknown-elf-objcopy main_riscv.elf -O verilog main_riscv.mem

clean:
	rm -f *.elf *.mem
	
