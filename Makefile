default:
	rm -rf program
	# riscv32-unknown-linux-gnu-as program.s -o program.o
	# riscv32-unknown-linux-gnu-gcc -o program program.o -nostdlib -static
	riscv64-linux-gnu-as program.s -o program.o
	riscv64-linux-gnu-gcc -o program program.o -nostdlib -static
