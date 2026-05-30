# GeoLang

Linguagem experimental voltada a problemas geoespaciais (rotas, distâncias, ordenação de dados georreferenciados). Este repositório contém as duas primeiras fases do compilador: o **analisador léxico** (scanner) e o **analisador sintático** (parser).

## Visão geral

O compilador da GeoLang opera como um transpilador: recebe código-fonte `.geo`, realiza análise léxica, sintática e semântica, e gera código C puro como saída. As duas primeiras fases estão implementadas.

O analisador léxico transforma o fluxo bruto de caracteres em tokens. O analisador sintático recebe esses tokens e verifica se eles formam estruturas gramaticalmente válidas segundo as regras da GeoLang, implementando um parser LALR(1) gerado pelo Bison.

Conforme descrito no *Modern Compiler Implementation* de Andrew Appel, a análise léxica é especificada por expressões regulares implementadas por um autômato finito determinístico (DFA), enquanto a análise sintática é especificada por uma gramática livre de contexto e implementada por um autômato de pilha.

## Estrutura

```
geolang/
├── src/
│   ├── lexer/
│   │   ├── scanner.l        # Regras léxicas (Flex)
│   │   ├── scanner.debug.l  # Versão debug com saída verbose dos tokens
│   │   └── tokens.h         # Enumeração dos tokens
│   └── parser/
│       └── parser.y         # Gramática e ações semânticas (Bison)
├── examples/
│   ├── minimo.geo           # Programa mínimo válido
│   ├── quicksort.geo        # Programa completo (Quicksort)
│   └── erro_sintatico.geo   # Exemplo de erro sintático
└── makefile
```

- **`scanner.l`** — Especificação Flex. Cada regra associa uma expressão regular a uma ação de retorno do token correspondente.
- **`scanner.debug.l`** — Versão idêntica ao `scanner.l` com `printf` em cada ação para rastrear o token e o texto reconhecido (`yytext`) durante o desenvolvimento.
- **`tokens.h`** — Define o `enum tokens` com códigos a partir de 256.
- **`parser.y`** — Especificação Bison. Define a gramática LALR(1) da GeoLang com regras de precedência de operadores e ações de diagnóstico para cada construção reconhecida.

## Categorias de tokens

| Categoria | Exemplos |
|-----------|----------|
| Palavras-chave | `fn`, `var`, `if`, `else`, `elseif`, `for`, `while`, `do`, `return`, `in`, `allocate` |
| Tipos primitivos | `int`, `float`, `bool`, `string`, `void`, `mut`, `struct` |
| Tipos geoespaciais | `Point`, `Line`, `Polygon`, `matrix` |
| Operadores | `+`, `-`, `*`, `/`, `=`, `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Pontuação | `;`, `:`, `,`, `.`, `..`, `->`, `()`, `{}`, `[]` |
| Literais | `TK_NUM` (inteiro), `TK_REAL` (ponto flutuante), `TK_STRING` |
| Identificadores | `TK_ID` — `[a-zA-Z_][a-zA-Z0-9_]*` |
| Ignorados | espaços, quebras de linha, comentários `// ...` |

## Compilação e execução

Pré-requisitos: `gcc`, `flex`, `bison`, `make`.

```sh
make           # compila lexer + parser → binário geolang
make test      # executa o parser sobre examples/quicksort.geo
make clean     # remove arquivos gerados
```

Entrada via `stdin`. Tokens não reconhecidos produzem `Erro léxico: caractere desconhecido`. Erros sintáticos reportam a linha e o token inesperado.

## Exemplos de execução

```sh
# Programa mínimo
./geolang < examples/minimo.geo

# Quicksort completo
./geolang < examples/quicksort.geo

# Erro sintático intencional
./geolang < examples/erro_sintatico.geo
```

## Próximos passos

- Construção da AST (Árvore Sintática Abstrata)
- Tabela de símbolos e análise semântica
- Geração de código intermediário com alvo em C (transpilação)
