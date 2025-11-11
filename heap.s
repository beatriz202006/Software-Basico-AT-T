section .note.GNU-stack progbits noalloc noexec nowrite

section .bss
heap_start: resq 1                          ; the beginning of the heap

section .text
global setup_brk
global dismiss_brk
global get_brk
global memory_alloc
global memory_free

; salva o endereço atual da heap
setup_brk:
    push rbp
    mov rbp, rsp

    mov rax, 12                             ; syscall _brk
    xor rdi, rdi
    syscall
    mov qword [heap_start], rax

    pop rbp
    ret

; restaura o topo da heap para o valor original salvo
dismiss_brk:
    push rbp
    mov rbp, rsp

    mov rax, 12
    mov rdi, [heap_start]
    syscall

    pop rbp
    ret

; retorna o endereço atual da heap
get_brk:
    push rbp
    mov rbp, rsp

    mov rax, 12
    xor rdi, rdi
    syscall

    pop rbp
    ret

memory_alloc:
    push rbp
    mov rbp, rsp

    ; verifica se existe bloco livre, inicializa  variáveis e pega o topo da heap atual
    ; variáveis locais: size_block, size_worst_block, ptr_worst_block e top_heap
    sub rsp, 32                             ; espaço para variáveis locais
    mov [rbp-8], rdi                        ; size_block (bytes requisitados)
    mov QWORD [rbp-16], 0                   ; size_worst_block = 0
    mov QWORD [rbp-24], 0                   ; ptr_worst_block = 0

    mov rax, 12
    xor rdi, rdi    
    syscall 
    mov [rbp-32], rax                       ; top_heap (limite de busca)

    mov rsi, [heap_start]                   ; rsi = ponteiro de iteração

    ; escolhe o maior bloco livre que caiba a requisição (worst-fit)
    _loop:  
        cmp rsi, [rbp-32]                   ; while i < top_heap
        jge _end_loop                       ; se chegou no fim da heap, sai do loop

        cmp BYTE [rsi], 1                   ; verifica se o bloco está ocupado (bit de uso = 1)
        je _next_block  

        mov rdx, [rsi+1]                    ; rdx = register[i] -> size_block (lê tamanho do bloco)
        cmp rdx, [rbp-8]                    ; se tamanho do bloco encontrado < solicitado, pula
        jl _next_block  

        mov rdx, [rbp-16]                   ; rdx = size_worst_block
        cmp rdx, [rsi+1]                    ; se já temos um bloco maior -> pula
        jg _next_block  

        mov rdx, [rsi+1]                    ; rdx = register[i]->size_block
        mov [rbp-16], rdx                   ; size_worst_block = register[i]->size_block (salva tamanho)
        mov [rbp-24], rsi                   ; ptr_worst_block = i (salva endereço)
        
        ; avança para o próximo bloco
        _next_block:    
            mov rdx, [rsi+1]                ; rdx = register[i]->size_block
            add rsi, 9                      ; soma 9 (header + uso)
            add rsi, rdx                    ; i++
            add rsi, 8                      ; soma o tamanho do bloco e 8 do footer
            jmp _loop  

    _end_loop:     
        mov rsi, [rbp-24]                   ; rsi = endereço do pior bloco (worst-fit) encontrado
        cmp QWORD rsi, 0                    ; verifica se ptr_worst_block == 0  (nenhum bloco livre encontrado)
        je _alloc_new_block                 ; se não encontrou, aloca novo bloco

        mov rdx, [rbp-16]   
        sub rdx, [rbp-8]                    ; extra_bytes = size_block - size_worst_block

        ; Testa se dá para fazer split do bloco (pelo menos 18 bytes)
        cmp rdx, 18                         ; se extra_bytes < 18 não dá para dividir
        jl _set_block   

        ; Split do bloco: atualiza o bloco atual para ter o tamanho exato requisitado e header e footer com o novo tamanho
        mov rbx, [rbp-8]                    ; rbx = size_block (tamanho requisitado)
        mov QWORD [rsi+1], rbx              ; register[ptr_worst_block]->size_block = size_block (header)
        mov QWORD [rsi+9+rbx], rbx          ; register[ptr_worst_block]->size_block = size_block (footer)

        ; Cria o novo bloco livre (o restante depois do split)
        lea rbx, [rsi+9+rbx+8]              ; rbx = endereço do novo bloco
        mov BYTE [rbx], 0                   ; new_register->valid = 0 (marca uso como livre)
        sub rdx, 17                         ; desconta metadados
        mov QWORD [rbx+1], rdx              ; new_register->size_block = extra_bytes (header)
        mov QWORD [rbx+9+rdx], rdx          ; new_register->size_block = extra_bytes (footer)
    
        ; Marca o bloco usado e retorna
        _set_block:
            mov BYTE [rsi], 1               ; register[ptr_worst_block]->valid = 1
            lea rax, [rsi+9]                ; retorna o endereço dos dados
            jmp _exit_alloc

        ; Se não havia bloco livre, cria novo
        _alloc_new_block:
            mov rax, 12                     ; sys_brk
            xor rdi, rdi                    ; reset rdi
            syscall                         ; call brk(0) => obtém o topo atual da heap

            mov rsi, rax                    ; início do novo bloco
            mov rbx, [rbp-8]                ; rbx = size_block (tamanho requisitado)
            add rax, 9                      
            add rax, 8                      
            add rax, rbx                    ; soma header, footer e dados
            mov rdi, rax                    ; novo topo da heap
            mov rax, 12                     ; sys_brk
            syscall                         
            
            ; Inicializa o novo bloco
            mov BYTE [rsi], 1               ; bit de uso = 1 (ocupado)
            mov QWORD [rsi + 1], rbx        ; header = tamanho
            mov QWORD [rsi + 9 + rbx], rbx  ; footer = tamanho
            lea rax, [rsi+9]                ; retorna endereço dos dados

        _exit_alloc:
            add rsp, 32
            pop rbp
            ret

memory_free:
    push rbp
    mov rbp, rsp

    cmp rdi, 0                              ; verifica se recebeu um ponteiro válido
    je _exit_error
    cmp BYTE [rdi-9], 0                     ; lê o byte de uso. Se for 0, retorna erro (não tenta free duas vezes)
    je _exit_error

    sub rdi, 9                              ; rdi aponta para o início do bloco
    mov BYTE [rdi], 0                       ; register->valid = 0 (livre)

    ; Preparação para fazer merges
    sub rsp, 32                             ; reserva 32 bytes na stack para variáveis locais temporárias
    mov [rbp - 8], rdi                      ; ponteiro base (início do bloco atual)
    mov rax, [rdi + 1]
    mov [rbp - 16], rax                     ; tamanho do bloco inicial
    mov rax, [heap_start]
    mov [rbp - 24], rax                     ; carrega heap_start e guarda em [rbp-24]

    mov rax, 12
    xor rdi, rdi
    syscall
    mov [rbp - 32], rax                     ; [rpb-32] = topo atual da heap
    xor rax, rax

    ; Tenta juntar com o bloco ant
    _loop_merge_behind:
        mov rdi, [rbp - 8]                  ; ponteiro do bloco atual
        sub rdi, 8                          ; rdi = endereco do tamanho do bloco anterior (footer)
        cmp rdi, [rbp - 24]                 ; se addr(footer) <= heap_start, não existe bloco anterior -> pula
        jle _loop_merge_ahead

        mov QWORD rdi, [rdi]                ; rdi = tamanho do bloco anterior
        mov rdx, [rbp - 8]                  ; ponteiro base atual 
        sub rdx, 8                          ; ponteiro esta no inicio do footer
        sub rdx, rdi                        ; ponteiro esta no inicio da area de dados
        sub rdx, 9                          ; rdx agora aponta para o início do header do bloco anterior
        cmp BYTE [rdx], 1                   ; se bloco anterior ocupado, pula
        je _loop_merge_ahead

        add rdi, [rbp - 16]                 ; rdi = size bloco anterior + size bloco atual
        add rdi, 17                         ; rdi = novo tamanho + metadados absorvidos
        mov [rdx + 1], rdi                  ; tamanho novo = rdi
        mov [rdx + 9 + rdi], rdi            ; footer
        mov [rbp - 8], rdx                  ; atualiza ponteiro atual para header do bloco resultante
        mov [rbp - 16], rdi                 ; novo tamanho atual
        jmp _loop_merge_behind
    
    ; Tenta juntar com o bloco da frente
    _loop_merge_ahead:
        mov rdi, [rbp - 8]                  ; ponteiro do bloco atual
        mov rdx, [rdi + 1]                  ; rdx = tamanho do bloco atual
        lea rdx, [rdi + 9 + rdx + 8]        ; rdx = ponteiro do header do próximo bloco
        cmp rdx, [rbp - 32]                 ; se rdx >= topo da heap -> pula
        jge _shrink_heap

        cmp BYTE [rdx], 1                   ; Se próximo bloco estiver ocupado, pula
        je _shrink_heap

        mov rdx, [rdx + 1]                  ; rdx = tamanho do próximo bloco
        add rdx, [rbp - 16]                 ; rdx = tamanho atual + tamanho proximo
        add rdx, 17                         ; rdx = novo tamanho + metadados absorvidos
        mov [rdi + 1], rdx                  ; header do bloco atual = novo tamanho
        mov [rdi + 9 + rdx], rdx            ; footer = novo tamanho
        mov [rbp - 16], rdx                 ; atualiza tamanho atual
        jmp _loop_merge_ahead
    
    ; Se o bloco final foi liberado, tenta encolher a heap
    _shrink_heap:
        mov rdx, [rbp - 8]
        add rdx, 9
        add rdx, [rbp - 16]
        add rdx, 8                          ; rdx = endereço do topo imediatamente após o bloco atual

        mov rax, 12
        xor rdi, rdi
        syscall
        cmp rdx, rax                        ; Se rdx == rax então o bloco está no final da heap (podemos reduzir o brk)
        jne _end_merge
        mov rax, 12                         ; move brk para o início do bloco (removendo fisicamente o bloco da heap)
        mov rdi, [rbp - 8]
        syscall  

        ; Limpa a stack e retorna rax = 0 (sucesso)
        _end_merge:
            add rsp, 32
            mov rax, 0
            jmp _exit_sucess

    ; Em caso de erro, rax = 1
    _exit_error:
        mov rax, 1
        jmp _exit_free

    _exit_sucess:
        mov rax, 0

    _exit_free:
        pop rbp
        ret