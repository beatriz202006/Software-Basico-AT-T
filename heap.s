global setup_brk           
global dismiss_brk
global memory_alloc
global memory_free
global heap_start          ; variável global para início da heap
global heap_end            ; variável global para fim atual da heap

section .data
heap_start:    dq 0       ; 8 bytes (quadword) para armazenar o início da heap, inicializado a 0
heap_end:      dq 0       ; 8 bytes para armazenar o fim atual da heap

section .text

; void setup_brk()
setup_brk:
    mov rax, 12            ; rax = 12 (syscall brk)
    xor rdi, rdi           ; rdi = 0, brk(0) consulta endereço atual da heap
    syscall                ; chama o kernel

    mov [heap_start], rax  ; salva endereço inicial da heap em heap_start
    mov [heap_end], rax    ; heap_end inicialmente é igual ao início
    ret                     ; retorna para a função chamadora

; void dismiss_brk()
dismiss_brk:
    mov rdi, [heap_start]  ; rdi = endereço inicial da heap
    mov rax, 12            ; syscall brk
    syscall                ; restaura o brk para o início da heap

    mov rax, [heap_start]  ; atualiza rax com heap_start
    mov [heap_end], rax    ; atualiza heap_end também
    ret

; void* memory_alloc(unsigned long bytes)
memory_alloc:
    push rbx               ; salva rbx (usado para percorrer a heap)
    push r8                ; salva r8 (endereço do maior bloco livre encontrado)
    push r9                ; salva r9 (tamanho do maior bloco livre encontrado)

    mov rbx, [rel heap_start]  ; rbx = início da heap
    mov r8, 0                  ; inicializa endereço do maior bloco livre com 0
    mov r9, 0                  ; inicializa tamanho do maior bloco livre com 0

; loop de busca pelo maior bloco livre (worst-fit)
.loop:
    cmp rbx, [rel heap_end]    ; verifica se chegou ao final da heap
    jge .no_free_block         ; se sim, pula para alocação de novo bloco

    mov al, [rbx]              ; lê byte de uso do bloco (0=livre,1=ocupado)
    mov rsi, [rbx + 1]         ; lê tamanho do bloco (8 bytes)

    cmp al, 0                  ; verifica se o bloco está livre
    jne .next                  ; se ocupado, pula para o próximo bloco

    cmp rsi, rdi               ; verifica se o tamanho do bloco >= solicitado
    jb .next                   ; se não, pula para o próximo bloco

    cmp rsi, r9                ; verifica se o tamanho é maior que o maior encontrado
    jbe .next                  ; se não, pula para o próximo bloco

    mov r8, rbx                ; atualiza endereço do maior bloco livre
    mov r9, rsi                ; atualiza tamanho do maior bloco livre

.next:
    lea rbx, [rbx + rsi + 9]   ; avança para o próximo bloco (dados + cabeçalho de 9 bytes)
    jmp .loop                  ; repete o loop

.no_free_block:
    cmp r8, 0                  ; verifica se algum bloco livre foi encontrado
    jne .use_existing          ; se sim, usa o bloco existente

    ; caso não tenha bloco livre adequado, cria novo bloco no final da heap
    mov rbx, [rel heap_end]    ; rbx = fim atual da heap
    mov byte [rbx], 1          ; marca como ocupado
    mov qword [rbx + 1], rdi   ; grava tamanho do bloco solicitado

    lea rsi, [rbx + rdi + 9]   ; calcula novo fim da heap (bloco + cabeçalho)
    mov [rel heap_end], rsi    ; atualiza heap_end

    mov rax, 12                 ; syscall brk
    mov rdi, rsi                ; rdi = novo fim da heap
    syscall                     ; expande a heap

    lea rax, [rbx + 9]          ; ponteiro de retorno = início dos dados do bloco
    jmp .fim

; usa bloco livre existente (worst-fit) e divide se houver espaço suficiente
.use_existing:
    mov byte [r8], 1            ; marca o bloco como ocupado
    mov rsi, r9                 ; rsi = tamanho total do bloco
    sub rsi, rdi                ; rsi = espaço restante após a alocação

    cmp rsi, 10                 ; verifica se sobra espaço suficiente para novo bloco (>=10)
    jl .no_split                ; se não, não fragmenta

    mov qword [r8 + 1], rdi     ; define tamanho do bloco atual = solicitado
    lea rbx, [r8 + rdi + 9]     ; calcula endereço do novo bloco
    mov byte [rbx], 0           ; novo bloco livre
    sub rsi, 9                   ; desconta cabeçalho
    mov qword [rbx + 1], rsi     ; tamanho do novo bloco livre
    jmp .retornar

.no_split:
    mov qword [r8 + 1], r9      ; mantém tamanho original do bloco

.retornar:
    lea rax, [r8 + 9]           ; retorna ponteiro para início dos dados do bloco
    jmp .fim

.fim:
    pop r9
    pop r8
    pop rbx
    ret

; int memory_free(void* ptr)
memory_free:
    mov rax, rdi                ; rax = ponteiro do usuário
    sub rax, 9                  ; retrocede para o início do cabeçalho
    mov byte [rax], 0           ; marca como livre
    xor eax, eax                ; retorna 0
    ret
