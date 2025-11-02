#include <stdio.h>
#include <stdint.h>

void setup_brk(void);
void dismiss_brk(void);
void *memory_alloc(unsigned long int bytes);
void memory_free(void *ptr);

extern unsigned long int heap_start;
extern unsigned long int heap_end;

void print_heap_map() {
    unsigned char *ptr = (unsigned char *)heap_start;

    while ((unsigned long int)ptr < heap_end) {
        unsigned char uso = *ptr;
        unsigned long tamanho = *(unsigned long*)(ptr + 1);
        printf("[uso=%u | tam=%lu]", uso, tamanho);
        ptr += 9 + tamanho;

        if ((unsigned long)ptr < heap_end) 
            printf(" -> ");
    }

    printf("\n");
}

int main() {
    setup_brk();

    printf("Heap inicial: %p\n", (void*)heap_start);

    // Alocações iniciais
    void *p1 = memory_alloc(10);
    void *p2 = memory_alloc(20);
    void *p3 = memory_alloc(5);

    printf("\nApós alocações iniciais:\n");
    print_heap_map();

    // Libera p2 (meio da heap)
    memory_free(p2);
    printf("\nApós liberar p2:\n");
    print_heap_map();

    // Aloca um bloco maior que p3, mas menor que p2 para testar worst-fit
    void *p4 = memory_alloc(15);
    printf("\nApós alocar p4 (15 bytes, deve usar o maior bloco livre - p2):\n");
    print_heap_map();

    // Libera p1 e p3
    memory_free(p1);
    memory_free(p3);
    printf("\nApós liberar p1 e p3:\n");
    print_heap_map();

    // Aloca blocos que devem causar split
    void *p5 = memory_alloc(8);
    void *p6 = memory_alloc(12);
    printf("\nApós alocar p5 (8 bytes) e p6 (12 bytes) com split:\n");
    print_heap_map();

    // Aloca bloco grande que não cabe em nenhum espaço livre
    void *p7 = memory_alloc(50);
    printf("\nApós alocar p7 (50 bytes) - deve criar novo bloco no final da heap:\n");
    print_heap_map();

    dismiss_brk();
    return 0;
}
