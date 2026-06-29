# GeoLang

Transpilador experimental para problemas geoespaciais. Recebe código `.geo`, realiza análise léxica, sintática e semântica (com tabela de símbolos e verificação de tipos), e gera código em subconjunto restrito de C — sem `if`/`while`/`for` estruturados; toda estrutura de controle vira `if (cond) goto L;` / `goto L;`.

```
.geo  →  Léxico (Flex/DFA)  →  Sintático (Bison/LALR(1))  →  Semântico  →  C reduzido
```

## Estrutura

```
geolang/
├── src/
│   ├── lexer/
│   │   ├── scanner.l           # regras léxicas (Flex)
│   │   ├── scanner.debug.l     # versão verbose (imprime cada token)
│   │   └── tokens.h
│   ├── parser/
│   │   └── parser.y            # gramática, semântica e geração de código (Bison)
│   ├── semantic/
│   │   ├── symbol_table.h/.c   # 3 tabelas hash: variáveis, structs, funções
│   │   └── test_symbol_table.c # 15 testes unitários
│   └── codegen/
│       ├── strbuf.h/.c         # buffer dinâmico para montar C gerado
│       └── label_gen.h/.c      # gerador de rótulos únicos L0, L1, ...
├── examples/                   # exemplos e casos de teste semântico
├── problemas/                  # 6 problemas da disciplina (.geo)
├── output/                     # .c gerados (criado automaticamente)
└── makefile
```

## Pré-requisitos

`gcc`, `flex`, `bison`, `make`

## Build e uso

```sh
make              # compila → binário geolang
make clean        # remove arquivos gerados

./geolang arquivo.geo              # lê arquivo; .c gerado em output/arquivo.c
./geolang arquivo.geo -o pasta/    # escolhe pasta de saída
./geolang < arquivo.geo            # stdin; .c gerado em output/out.c
```

## Alvos do make

| Alvo | O que faz |
|------|-----------|
| `make test-all` | Build + 15 testes unitários + todos os `.geo` de `examples/` e `problemas/`, com resumo OK/erro |
| `make test-symbols` | Compila e roda os 15 testes unitários da tabela de símbolos |
| `make test` | Roda parser sobre `examples/quicksort.geo` |
| `make test-minimo` | Roda parser sobre `examples/minimo.geo` |
| `make test-erro` | Roda sobre `examples/erro_sintatico.geo` (erro esperado) |
| `make debug` | Build com `scanner.debug.l` (mostra cada token reconhecido) |
| `make codegen-check FILE=<f>` | Gera C reduzido de `<f>` e valida com `gcc -c` |
| `make run FILE=<f>` | Gera C, compila com gcc e executa, mostrando saída real |

```sh
# rodar toda a bateria de uma vez
make test-all

# compilar e executar o C gerado de um problema
make run FILE=problemas/problema1.geo
```

## Problemas do professor

| Arquivo | Descrição |
|---------|-----------|
| `problema1.geo` | Expressão aritmética simples |
| `problema2.geo` | Leitura em loop + classificação por faixas |
| `problema3.geo` | Soma e produto de matrizes |
| `problema4.geo` | Números racionais com `struct rational_t` |
| `problema5.geo` | MDC recursivo com parâmetro por referência |
| `problema6.geo` | Árvore binária de busca (insert, min, max, print por nível) |

```sh
make clean && make
./geolang problemas/problema1.geo   # → output/problema1.c
gcc -o /tmp/p1 output/problema1.c && /tmp/p1
```

## Tokens

| Categoria | Exemplos |
|-----------|----------|
| Palavras-chave | `fn`, `var`, `if`, `else`, `elseif`, `for`, `while`, `do`, `return`, `in`, `allocate` |
| Tipos primitivos | `int`, `float`, `bool`, `string`, `void`, `mut`, `struct` |
| Tipos geoespaciais | `Point`, `Line`, `Polygon`, `matrix` |
| Operadores | `+` `-` `*` `/` `=` `==` `!=` `<` `>` `<=` `>=` |
| Literais | `TK_NUM` (int), `TK_REAL` (float), `TK_STRING`, `true`, `false` |
| Identificadores | `[a-zA-Z_][a-zA-Z0-9_]*` |

## Limitações conhecidas

- Concatenação de strings (`"a" + "b"`) traduz para `+` de C (inválido para `char*`).
- `io.print` / `io.read_int` / `io.read_float` são embutidos — não passam pela tabela de subprogramas.
- `allocate(n)` → `malloc(n * sizeof(float))` — tipo de elemento fixo em `float`.
