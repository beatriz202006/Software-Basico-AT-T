CC = gcc
CFLAGS = -Wall -no-pie
ASMFLAGS = -Wall -no-pie -c

# alvo principal
all: main

# compila o arquivo assembly AT&T (usando gcc)
heap.o: heap.s
	$(CC) $(ASMFLAGS) heap.s -o heap.o

# compila o programa principal
main: heap.o main.c
	$(CC) $(CFLAGS) -o main main.c heap.o

# executa o programa
run: main
	./main

# limpa os arquivos gerados
clean:
	rm -f *.o main
