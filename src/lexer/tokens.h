#ifndef TOKENS_H
#define TOKENS_H

enum tokens {
    TK_ID = 256,
    TK_NUM,
    TK_REAL,
    TK_STRING,

    /* tipos escalares */
    TK_INT,
    TK_FLOAT,
    TK_BOOL,
    TK_VOID,

    /* modificadores e estruturas */
    TK_MUT,
    TK_STRUCT,

    /* tipos geométricos */
    TK_POINT,
    TK_LINE,
    TK_POLYGON,
    TK_MATRIX,

    /* palavras-chave de controle */
    TK_FN,
    TK_VAR,
    TK_IF,
    TK_FOR,
    TK_WHILE,
    TK_DO,
    TK_ELSE,
    TK_ELSEIF,
    TK_RETURN,
    TK_IN,
    TK_ALLOCATE,

    /* operadores relacionais */
    TK_EQ,
    TK_NEQ,
    TK_GREATER,
    TK_LESS,
    TK_GEQ,
    TK_LEQ,

    /* operadores aritméticos e atribuição */
    TK_ASSIGN,
    TK_SHORT_DECL,
    TK_SUM,
    TK_MIN,
    TK_MUL,
    TK_DIV,

    /* operadores especiais */
    TK_ARROW,
    TK_RANGE,

    /* pontuação */
    TK_COMMA,
    TK_DOT,
    TK_COLON,
    TK_SEMI,
    TK_LBRACK,
    TK_RBRACK,
    TK_LCURLY,
    TK_RCURLY,
    TK_LPAREN,
    TK_RPAREN,

    TK_EOF
};

#endif /* TOKENS_H */
