# GeoLang

Linguagem experimental voltada a problemas geoespaciais (rotas, distâncias, ordenação de dados georreferenciados). Este repositório contém a primeira fase do compilador: o **analisador léxico** (scanner).

## Visão geral

O analisador léxico é a porta de entrada do compilador. Sua função é transformar o fluxo bruto de caracteres do código-fonte em uma sequência de **tokens** (unidades atômicas como identificadores, palavras-chave, literais e operadores).

Conforme descrito no *Modern Compiler Implementation* de Andrew Appel, a análise léxica é especificada por **expressões regulares** e implementada por um **autômato finito determinístico (DFA)**.

## Estrutura

```
geolang/
├── src/lexer/
│   ├── scanner.l    # Regras léxicas (Flex)
│   └── tokens.h     # Enumeração dos tokens
├── examples/
│   └── quicksort.geo
└── makefile
```

- **`scanner.l`** — Especificação Flex. Cada regra associa uma expressão regular a uma ação (retorno do token correspondente). É o equivalente direto às tabelas de transição derivadas das regex no capítulo 2 do Appel.
- **`tokens.h`** — Define o `enum tokens` com códigos a partir de 256.

## Categorias de tokens

| Categoria | Exemplos |
|-----------|----------|
| Palavras-chave | `fn`, `var`, `if`, `else`, `elseif`, `for`, `while`, `do`, `return`, `in` |
| Operadores | `+`, `-`, `*`, `/`, `=`, `==`, `!=`, `<`, `>`, `<=`, `>=` |
| Pontuação | `;`, `:`, `,`, `.`, `..`, `->`, `()`, `{}`, `[]` |
| Literais | `TK_NUM` (inteiro), `TK_REAL` (ponto flutuante), `TK_STRING` |
| Identificadores | `TK_ID` — `[a-zA-Z_][a-zA-Z0-9_]*` |
| Ignorados | espaços, quebras de linha, comentários `// ...` |

A ordem das regras importa: palavras-chave precedem `TK_ID` para evitar que `if` seja classificado como identificador — aplicação direta da regra de **longest match** com **prioridade por ordem de declaração**, descrita por Appel (seção 2.4).

## Compilação e execução

Pré-requisitos: `gcc`, `flex`, `make`.

```sh
make           # gera build/lexer
make test      # executa o lexer sobre examples/quicksort.geo
make clean     # remove build/
```

Entrada via `stdin`. Tokens não reconhecidos produzem `Erro: caractere desconhecido <c>`.

## Próximos passos

- Análise sintática (parser)
- Construção de AST e análise semântica
- Geração de código intermediário com alvo em C (transpilação)
