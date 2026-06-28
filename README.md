# GeoLang

Linguagem experimental voltada a problemas geoespaciais (rotas, distâncias, ordenação de dados georreferenciados). Este repositório contém o compilador completo: **analisador léxico**, **analisador sintático**, **análise semântica com tabela de símbolos** e **gerador de código C reduzido**.

## Visão geral

O compilador da GeoLang opera como um transpilador: recebe código-fonte `.geo`, realiza análise léxica, sintática e semântica (com verificação de tipos), e gera código em um subconjunto restrito de C como saída — usando apenas blocos, sequenciamento, atribuição, chamadas de função, `goto`/rótulos e `return`, sem nenhum comando de iteração ou seleção estruturado (toda estrutura de controle da GeoLang é traduzida para `if (cond) goto L;` e `goto L;`).

Conforme descrito no *Modern Compiler Implementation* de Andrew Appel e no *Compilers: Principles, Techniques and Tools* (Aho, Lam, Sethi, Ullman), o compilador segue o pipeline clássico:

```
código-fonte (.geo)
        │
        ▼
  Análise Léxica      → tokens (Flex / DFA)
        │
        ▼
  Análise Sintática   → árvore de derivação (Bison / LALR(1))
        │
        ▼
  Análise Semântica    → tabela de símbolos + verificação de tipos
        │
        ▼
  Geração de Código    → C reduzido (goto/labels)
```

A análise léxica é especificada por expressões regulares implementadas por um autômato finito determinístico (DFA). A análise sintática é especificada por uma gramática livre de contexto implementada por um autômato de pilha (LALR(1)). A análise semântica e a geração de código seguem o esquema de **tradução dirigida pela sintaxe**: cada produção da gramática sintetiza atributos (tipo e fragmento de código C) a partir dos atributos de seus filhos.

Quando a análise termina sem erro semântico, o código C gerado não é só impresso no terminal: é salvo em disco dentro da pasta `output/`, com o mesmo nome-base do `.geo` de entrada (ex.: `problemas/problema1.geo` → `output/problema1.c`), pronto para ser compilado com `gcc`.

## Estrutura

```
geolang/
├── src/
│   ├── lexer/
│   │   ├── scanner.l         # Regras léxicas (Flex)
│   │   ├── scanner.debug.l   # Versão debug com saída verbose dos tokens
│   │   └── tokens.h          # Referência histórica dos códigos de token
│   ├── parser/
│   │   └── parser.y          # Gramática, análise semântica e geração de código (Bison)
│   ├── semantic/
│   │   ├── symbol_table.h    # 3 tabelas de símbolos (variáveis, structs, funções)
│   │   ├── symbol_table.c
│   │   └── test_symbol_table.c  # 15 testes unitários da tabela de símbolos
│   └── codegen/
│       ├── strbuf.h          # Buffer de string dinâmico (montagem do C gerado)
│       ├── strbuf.c
│       ├── label_gen.h       # Gerador de rótulos únicos (L0, L1, L2...)
│       └── label_gen.c
├── examples/
│   ├── minimo.geo                  # Programa mínimo válido
│   ├── quicksort.geo                # Programa completo (Quicksort)
│   ├── erro_sintatico.geo           # Exemplo de erro sintático
│   ├── teste_fatorial.geo           # Recursão
│   ├── teste_loops.geo              # while + do-while
│   ├── teste_elseif.geo             # if/elseif/else em cadeia
│   └── teste_*.geo                  # Demais casos de teste semântico (erros propositais)
├── problemas/
│   ├── problema1.geo                # Lista de exercícios do professor: expressão aritmética
│   └── problema2.geo                # Lista de exercícios do professor: leitura em loop + faixas
├── output/                          # Código C gerado (criado automaticamente, um .c por entrada)
└── makefile
```

- **`scanner.l`** — Especificação Flex. Cada regra associa uma expressão regular a uma ação de retorno do token correspondente, preenchendo `yylval` para os tokens com valor (identificadores, literais).
- **`scanner.debug.l`** — Versão idêntica ao `scanner.l` com `printf` em cada ação para rastrear o token e o texto reconhecido (`yytext`) durante o desenvolvimento.
- **`parser.y`** — Especificação Bison. Define a gramática LALR(1) da GeoLang, com:
  - Ações semânticas que populam as três tabelas de símbolos;
  - Verificação de tipos (widening permitido, narrowing bloqueado, condições booleanas, assinaturas de função, etc.);
  - Síntese de código C reduzido para cada construção (expressões, declarações, estruturas de controle).
- **`symbol_table.h/.c`** — Três tabelas hash independentes: variáveis (com pilha de escopos para lexical scoping), tipos definidos pelo usuário (`struct`) e subprogramas (funções), conforme orientação do professor.
- **`strbuf.h/.c`** — Buffer de string dinâmico usado para montar os fragmentos de código C durante o parsing.
- **`label_gen.h/.c`** — Gerador de rótulos únicos (`L0`, `L1`, ...) usado na tradução de `if/elseif/else`, `while`, `do-while` e `for` para `goto`.

## Categorias de tokens

| Categoria | Exemplos |
|-----------|----------|
| Palavras-chave | `fn`, `var`, `if`, `else`, `elseif`, `for`, `while`, `do`, `return`, `in`, `allocate` |
| Tipos primitivos | `int`, `float`, `bool`, `string`, `void`, `mut`, `struct` |
| Tipos geoespaciais | `Point`, `Line`, `Polygon`, `matrix` |
| Literais booleanos | `true`, `false` |
| Operadores | `+`, `-`, `*`, `/`, `=`, `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Pontuação | `;`, `:`, `,`, `.`, `..`, `->`, `()`, `{}`, `[]` |
| Literais | `TK_NUM` (inteiro), `TK_REAL` (ponto flutuante), `TK_STRING` |
| Identificadores | `TK_ID` — `[a-zA-Z_][a-zA-Z0-9_]*` |
| Ignorados | espaços, quebras de linha, comentários `// ...` |

## Compilação e execução

Pré-requisitos: `gcc`, `flex`, `bison`, `make`.

```sh
make              # compila lexer + parser + semântica + codegen → binário geolang
make clean        # remove arquivos gerados
```

O binário `geolang` aceita dois modos de entrada:

```sh
./geolang < arquivo.geo          # le da stdin (modo original); .c gerado vai para output/out.c
./geolang caminho/arquivo.geo    # le do arquivo informado; .c gerado vai para output/arquivo.c
./geolang caminho/arquivo.geo -o outra_pasta   # escolhe a pasta de saida do .c gerado (padrao: output/)
```

Tokens não reconhecidos produzem `Erro lexico: caractere desconhecido`. Erros sintáticos reportam a linha e o token inesperado. Erros semânticos reportam a linha e a descrição do problema (tipo incompatível, variável não declarada, etc.), sem interromper a análise no primeiro erro.

Se a análise terminar sem nenhum erro semântico, o compilador imprime o código C reduzido equivalente ao programa no terminal **e** salva o mesmo conteúdo em `output/<nome>.c` (pasta criada automaticamente).

### Compilação no Windows (`makefile.windows`)

Pré-requisitos: `gcc` (MinGW/MSYS2), `flex` e `bison` (GnuWin32) e `make`. Ajuste, no topo do arquivo, as variáveis `MINGW_BIN` e `GNUWIN_BIN` caso suas ferramentas estejam em outros diretórios (padrão: `C:\msys64\mingw64\bin` e `C:\GnuWin32\bin`); elas são injetadas no `PATH` apenas durante cada receita.

```powershell
# build do compilador (gera geolang.exe)
make -f makefile.windows

# gera o .c, compila com gcc e EXECUTA o programa traduzido
make -f makefile.windows run FILE=problemas/problema5.geo
make -f makefile.windows run FILE=problemas/problema6.geo

# remove os arquivos gerados
make -f makefile.windows clean
```

> O alvo `run` é interativo (os programas leem do teclado via `io.read_int`). Para testar com entrada automática, redirecione um arquivo direto no executável gerado: `output\problema6.exe < entrada.txt`. Se o seu `make` for `mingw32-make`, troque `make` por `mingw32-make`.

## Exemplos de execução

```sh
# Programa mínimo
./geolang < examples/minimo.geo

# Quicksort completo
./geolang < examples/quicksort.geo

# Erro sintático intencional
./geolang < examples/erro_sintatico.geo

# Recursão (fatorial)
./geolang < examples/teste_fatorial.geo

# while e do-while
./geolang < examples/teste_loops.geo

# if/elseif/else em cadeia
./geolang < examples/teste_elseif.geo
```

### Lista de exercícios do professor (`problemas/`)

```sh
make clean
make
./geolang problemas/problema1.geo    # gera output/problema1.c
./geolang problemas/problema2.geo    # gera output/problema2.c
```

### Testando de verdade (compilar e executar o C gerado)

```sh
gcc -o /tmp/p1 output/problema1.c && /tmp/p1
# esperado: 14.250000

gcc -o /tmp/p2 output/problema2.c && /tmp/p2
# pede numeros um a um; digite alguns valores e termine com um negativo
```

## Alvos auxiliares do makefile

```sh
make test           # roda o parser sobre examples/quicksort.geo
make test-minimo     # roda o parser sobre examples/minimo.geo
make test-erro       # roda o parser sobre examples/erro_sintatico.geo (erro esperado)
make test-symbols    # compila e roda os 15 testes unitários da tabela de símbolos
make debug           # build alternativo usando scanner.debug.l (mostra cada token)

# Valida que o C reduzido gerado para um programa realmente compila com gcc:
make codegen-check FILE=examples/teste_fatorial.geo

# Gera o C reduzido, compila com gcc e EXECUTA, mostrando a saida real:
make run FILE=problemas/problema1.geo
```

## Limitações conhecidas

- A concatenação de strings (`"a" + "b"`) é traduzida literalmente para o operador `+` de C, que não é válido para `char*`. Não há, no subconjunto de C definido pelo Anexo I, uma função de runtime para concatenação — esta é uma limitação documentada da implementação atual.
- O módulo `io` (`io.print`, `io.read_int`, `io.read_float`) é tratado como namespace embutido e não passa pela tabela de subprogramas; as chamadas são traduzidas diretamente para `printf`/funções auxiliares esperadas em tempo de execução.
- `allocate(n)` é traduzido para `malloc(n * sizeof(float))`, assumindo elemento `float` por padrão — outros tipos de elemento de array ainda não são totalmente propagados ao gerador de código.

## Próximos passos

- Resolver a limitação de concatenação de strings (ex: função de runtime auxiliar dentro do subconjunto permitido)
- Geração de código para `struct` com inicialização de campos
- Documentação final consolidada (PDF) com a especificação completa da linguagem