CC = gcc
ASM = nasm
CFLAGS = -no-pie -Wall
ASMFLAGS = -f elf64

all: main

heap.o: heap.s
	$(ASM) $(ASMFLAGS) heap.s -o heap.o

main: heap.o main.c
	$(CC) $(CFLAGS) -o main main.c heap.o

run: main
	./main

clean:
	rm -f *.o main