    .section .data              # seção de dados (variáveis globais)
    .globl heap_start
    .globl heap_end

heap_start:
    .quad 0                     # reserva uma quadword (8 bytes), inicilizada em 0
heap_end:
    .quad 0                     # outra quadword para armazenar o fim atual do brk

    .section .text              # seção de código
    .globl setup_brk            # exporta a função setup_brk
    .globl dismiss_brk          # exporta a função dismiss_brk
    .globl memory_alloc         # exporta a função memory_alloc
    .globl memory_free          # exporta a função memory_free

# void setup_brk: Obtém o brk atual (chamada de sistema brk(0) -> syscall número 12) e salva
setup_brk:
    movq $12, %rax              # rax = 12 => número da syscall `brk` em x86-64
    xorq %rdi, %rdi             # rdi = 0 => argumento 0 para brk(0) - consulta brk atual
    syscall

    movq %rax, heap_start(%rip) # [RIP + offset(heap_start)] = rax => grava heap_start = rax
    movq %rax, heap_end(%rip)   # grava heap_end = rax

    ret                         # retorno da função


# void dismiss_brk: Restaura o brk para o valor salvo em heap_start
dismiss_brk:
    movq heap_start(%rip), %rdi  # rdi = heap_start (endereço original da heap)
    movq $12, %rax               # rax = 12 => número da syscall `brk`
    syscall

    movq heap_start(%rip), %rax  # rax = heap_start (valor restaurado)
    movq %rax, heap_end(%rip)    # heap_end = heap_start

    ret                          # retorno da função


# void* memory_alloc(unsigned long int bytes): Implementa a estratégia worst-fit para alocação na heap
memory_alloc:
    push %rbx                    # salva ponteiro para bloco atual
    push %r8                     # salva endereco do bloco worst fit
    push %r9                     # salva tamanho do bloco worst fit

    movq heap_start(%rip), %rbx  #rbx = início da heap
    movq $0, %r8
    movq $0, %r9


# Loop de busca do maior bloco livre (worst-fit)
.loop:
    cmpq heap_end(%rip), %rbx    # compara para verificar se chegou ao fim da heap
    jge .no_free_block           # se rbx >= heap_end, não há mais blocos

    movb (%rbx), %al             # lê byte de uso (al)
    movq 1(%rbx), %rsi           # lê tamanho do bloco (8 bytes)

    cmpb $0, %al                # compara al com 0 para verificar o byte de uso (se está livre)
    jne .next                    # se o bloco está ocupado, pula

    cmpq %rdi, %rsi              # compara para verificar se tamanho encontrado (rsi) >= requisitado (rdi)
    jb .next                     # salta para .next se o tamanho encontrado < requisitado

    cmpq %r9, %rsi              # compara para verificar se o tamanho enocntrado é maior que o atual
    jbe .next                    # se não for maior, pula

    movq %rbx, %r8               # se for maior, r8 = endereço do maior bloco
    movq %rsi, %r9               # r9 = tamanho do maior bloco

.next:
    leaq 9(%rbx, %rsi), %rbx     # avança: rbx = endereço do próximo bloco
    jmp .loop                    # volta para o inicio do loop


# Se não achou bloco livre, cria um novo bloco:
.no_free_block:
    cmpq $0, %r8                 # compara para verificar se o maior bloco está livre
    jne .use_existing            # achou um bloco livre adequado

    # Se não achou o bloco livre, cria novo bloco no final da heap:
    movq heap_end(%rip), %rbx    # rbx = heap_end
    movb $1, (%rbx)              # marca byte de uso = 1 (ocupado)
    movq %rdi, 1(%rbx)           # tamanho = bytes requisitados

    leaq 9(%rbx, %rdi), %rsi    # novo fim da heap (header + dados)
    movq %rsi, heap_end(%rip)   # heap_end = novo fim 

    # expande a heap com a syscall brk
    movq $12, %rax
    movq %rsi, %rdi
    syscall

    leaq 9(%rbx), %rax           # retorno = ponteiro para dados
    jmp .fim

# usa bloco livre existente (worst fit encontrado) e divide se couber 10 bytes (9 de matadados + 1 de alocação)
.use_existing:
    movb $1, (%r8)               # marca bloco como ocupado (uso = 1)
    movq %r9, %rsi               # rsi = tamanho total do bloco livre
    subq %rdi, %rsi              # rsi = espaço restante do bloco depois da alocação

    cmpq $10, %rsi               # compara para verificar se sobra >= 10 bytes
    jl .no_split                 # se sobra < 10 bytes, não fragmenta o bloco

    # Split do bloco:
    movq %rdi, 1(%r8)            # define tamanho = solicitado
    leaq 9(%r8, %rdi), %rbx      #rbx = endereço do novo bloco (após metadados)

    movb $0, (%rbx)              # novo bloco: uso = 0 (livre)
    subq $9, %rsi                # desconta metadados do espaço restante
    movq %rsi, 1(%rbx)           # grava tamanho do novo bloco livre
    jmp .retornar

.no_split:
    movq %r9, 1(%r8)

.retornar:
    leaq 9(%r8), %rax            # retorno = endereço da área de dados
    jmp .fim

.fim:
    pop %r9
    pop %r8
    pop %rbx
    ret                          # retorno da função


# int memory_free(void *pointer): Marca um bloco ocupado como livre
memory_free:
    movq %rdi, %rax              # rax = ponteiro recebido
    subq $9, %rax                # volta 9 bytes (início do cabeçalho)
    movb $0, (%rax)              # marca byte de uso = 0 (livre)
    xorl %eax, %eax              # retorno = 0
    ret                          # retorno da função
