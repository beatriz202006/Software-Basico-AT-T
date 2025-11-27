# Relatório – Análise do programa *pass*

**Nome:** Beatriz Pontes Camargo – GRR 20242966 

---

## Etapas da análise

### 1) Função `main`
Através do comando:

```bash
objdump -d pass
```

foi possível identificar o fluxo do programa. 

Na função `main`, observou-se o seguinte trecho:

```
mov $0xb, %edx        # edx = 11
mov %rax, %rsi        # rsi = rax (endereço 0x4038)
call 1050 <read@plt>  # chamada da leitura da senha
```

Isso corresponde a:

```
read(0, 0x4038, 11)
```

Ou seja, o programa lê até 11 bytes da entrada padrão e os armazena em `input1` (endereço `0x4038`). Dessa forma, já é possível concluir que a senha tem **11 caracteres**.

Após a leitura, o código executa:

```
call <validate>
test %eax, %eax
```

O valor de retorno de `validate` (armazenado em `eax`) é testado para decidir se a senha está correta ou não.

---

### 2) Função `validate`
A função `validate` chama três outras funções em sequência:

1. `dec` 
2. `sub` 
3. `check` (com parâmetro `0x77`, que em decimal é `119`, correspondente ao caractere `'w'` em ASCII)

---

#### a) Função `dec`
A função `dec` opera sobre a região de memória `input0` (endereço `0x4048`). Já as funções `sub` e `check` trabalham sobre `input1` (`0x4038`). Como apenas `input1` é usado na verificação final, as alterações feitas por `dec` não têm impacto na validação da senha (sendo, portanto, irrelevante neste contexto).

---

#### b) Função `check`
O parâmetro passado para `check` é `0x77` (`'w'`). O código faz:

- Itera sobre os 11 bytes de `input1` (`i = 0..10`).
- Compara cada byte com `0x77`.
- Se algum byte for diferente, retorna `0` (falha). 
- Se todos forem iguais, retorna `1` (sucesso).

Assim, **a função `check` exige que, após as transformações, todos os 11 caracteres sejam iguais a `'w'`.**

---

#### c) Função `sub`
A função `sub` modifica cada byte de `input1` somando um incremento específico:

```
índice : incremento
0  : +20
1  : +22
2  : +14
3  : +2
4  : +9
5  : +8
6  : +21
7  : +22
8  : +14
9  : +3
10 : +56
```

Ou seja:

```
input1[i] = input1[i] + incremento[i]
```

Como `check` exige que, **após** essa soma, cada byte seja igual a `119` (`'w'`), é necessário que o valor digitado seja:

```
input1[i] = 119 - incremento[i]
```

---

### 3) Decodificação da senha
Realizando os cálculos:

- índice 0: 119 − 20 = 99  → `'c'`
- índice 1: 119 − 22 = 97  → `'a'`
- índice 2: 119 − 14 = 105 → `'i'`
- índice 3: 119 − 2  = 117 → `'u'`
- índice 4: 119 − 9  = 110 → `'n'`
- índice 5: 119 − 8  = 111 → `'o'`
- índice 6: 119 − 21 = 98  → `'b'`
- índice 7: 119 − 22 = 97  → `'a'`
- índice 8: 119 − 14 = 105 → `'i'`
- índice 9: 119 − 3  = 116 → `'t'`
- índice 10: 119 − 56 = 63 → `'?'`

Juntando os caracteres: 

```
caiunobait?
```

---

### 4) Resultado
Ao executar o programa com a senha correta:

```bash
./pass
password: caiunobait?
hell yeahhh!!!
```

---

## Conclusão
Através da análise do código assembly foi possível identificar a sequência de transformações aplicadas à entrada do usuário. Após reverter essas operações, concluiu-se que a senha correta é **`caiunobait?`**, validada com sucesso pelo programa.
