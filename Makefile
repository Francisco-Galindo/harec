default:
	rm -rf program
	riscv32-unknown-linux-gnu-as hello.s -o program.o
	riscv32-unknown-linux-gnu-gcc -o program program.o -nostdlib -static 
