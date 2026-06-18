%{
#include <stdio.h>
#include <stdlib.h>

extern int  yylex(void);
extern char *yytext;
extern int  yylineno;

void yyerror(const char *msg);
%}

/* ---------------------------------------------------------- */
/* Declaração de tokens                                        */
/* ---------------------------------------------------------- */
%token TK_ID TK_NUM TK_REAL TK_STRING

%token TK_INT TK_FLOAT TK_BOOL TK_VOID
%token TK_MUT TK_STRUCT
%token TK_POINT TK_LINE TK_POLYGON TK_MATRIX

%token TK_FN TK_VAR TK_IF TK_FOR TK_WHILE TK_DO
%token TK_ELSE TK_ELSEIF TK_RETURN TK_IN TK_ALLOCATE

%token TK_EQ TK_NEQ TK_GREATER TK_LESS TK_GEQ TK_LEQ
%token TK_ASSIGN
%token TK_SUM TK_MIN TK_MUL TK_DIV
%token TK_ARROW TK_RANGE

%token TK_COMMA TK_DOT TK_COLON TK_SEMI
%token TK_LBRACK TK_RBRACK
%token TK_LCURLY TK_RCURLY
%token TK_LPAREN TK_RPAREN

/* ---------------------------------------------------------- */
/* Precedência (menor para maior, de cima para baixo)         */
/* ---------------------------------------------------------- */
%left TK_EQ TK_NEQ
%left TK_LESS TK_GREATER TK_LEQ TK_GEQ
%left TK_SUM TK_MIN
%left TK_MUL TK_DIV
%right UNARY_MINUS

%%

/* ---------------------------------------------------------- */
/* Programa                                                    */
/* ---------------------------------------------------------- */

program
    : decl_list
    ;

decl_list
    : decl_list decl
    | decl
    ;

decl
    : fn_decl
    | struct_decl
    ;

/* ---------------------------------------------------------- */
/* Declaração de função                                        */
/* ---------------------------------------------------------- */

fn_decl
    : TK_FN TK_ID TK_LPAREN param_list TK_RPAREN ret_type
      TK_LCURLY stmt_list TK_RCURLY
    | TK_FN TK_ID TK_LPAREN TK_RPAREN ret_type
      TK_LCURLY stmt_list TK_RCURLY
    ;

ret_type
    : TK_ARROW type
    | TK_ARROW TK_VOID
    | /* vazio: retorno void implícito */
    ;

/* ---------------------------------------------------------- */
/* Parâmetros                                                  */
/* ---------------------------------------------------------- */

param_list
    : param_list TK_COMMA param
    | param
    ;

param
    : TK_ID TK_COLON TK_MUT type
    | TK_ID TK_COLON type
    ;

/* ---------------------------------------------------------- */
/* Declaração de struct                                        */
/* ---------------------------------------------------------- */

struct_decl
    : TK_STRUCT TK_ID TK_LCURLY field_list TK_RCURLY
    ;

field_list
    : field_list field
    | field
    ;

field
    : TK_ID TK_COLON type TK_SEMI
    ;

/* ---------------------------------------------------------- */
/* Tipos                                                       */
/* ---------------------------------------------------------- */

type
    : TK_INT
    | TK_FLOAT
    | TK_BOOL
    | TK_STRING
    | TK_POINT
    | TK_LINE
    | TK_POLYGON
    | TK_MATRIX
    | TK_LBRACK type TK_RBRACK
    | TK_ID
    ;

/* ---------------------------------------------------------- */
/* Statements                                                  */
/* ---------------------------------------------------------- */

stmt_list
    : stmt_list stmt
    |
    ;

stmt
    : var_decl
    | assign_stmt
    | if_stmt
    | for_stmt
    | while_stmt
    | do_while_stmt
    | return_stmt
    | expr_stmt
    ;

/* var x: tipo = expr; */
/* var x: tipo;        */
/* var x = expr;       */
var_decl
    : TK_VAR TK_ID TK_COLON type TK_ASSIGN expr TK_SEMI
    | TK_VAR TK_ID TK_COLON type TK_SEMI
    | TK_VAR TK_ID TK_ASSIGN expr TK_SEMI
    ;

assign_stmt
    : lvalue TK_ASSIGN expr TK_SEMI
    ;

lvalue
    : TK_ID
    | TK_ID TK_LBRACK expr TK_RBRACK
    | TK_ID TK_DOT TK_ID
    ;

/* ---------------------------------------------------------- */
/* Estruturas de controle                                      */
/* ---------------------------------------------------------- */

if_stmt
    : TK_IF expr TK_LCURLY stmt_list TK_RCURLY elseif_chain else_part
    ;

elseif_chain
    : elseif_chain TK_ELSEIF expr TK_LCURLY stmt_list TK_RCURLY
    |
    ;

else_part
    : TK_ELSE TK_LCURLY stmt_list TK_RCURLY
    |
    ;

for_stmt
    : TK_FOR TK_ID TK_IN expr TK_RANGE expr TK_LCURLY stmt_list TK_RCURLY
    ;

while_stmt
    : TK_WHILE expr TK_LCURLY stmt_list TK_RCURLY
    ;

do_while_stmt
    : TK_DO TK_LCURLY stmt_list TK_RCURLY TK_WHILE expr TK_SEMI
    ;

return_stmt
    : TK_RETURN expr TK_SEMI
    | TK_RETURN TK_SEMI
    ;

expr_stmt
    : expr TK_SEMI
    ;

/* ---------------------------------------------------------- */
/* Expressões                                                  */
/* ---------------------------------------------------------- */

expr
    : expr TK_EQ  expr
    | expr TK_NEQ expr
    | expr TK_LESS    expr
    | expr TK_GREATER expr
    | expr TK_LEQ     expr
    | expr TK_GEQ     expr
    | expr TK_SUM expr
    | expr TK_MIN expr
    | expr TK_MUL expr
    | expr TK_DIV expr
    | TK_MIN expr %prec UNARY_MINUS
    | postfix_expr
    ;

postfix_expr
    /* arr[i] */
    : TK_ID TK_LBRACK expr TK_RBRACK
    /* io.print(args) */
    | TK_ID TK_DOT TK_ID TK_LPAREN arg_list TK_RPAREN
    | TK_ID TK_DOT TK_ID TK_LPAREN TK_RPAREN
    /* func(args) */
    | TK_ID TK_LPAREN arg_list TK_RPAREN
    | TK_ID TK_LPAREN TK_RPAREN
    /* acesso a campo: p.x */
    | TK_ID TK_DOT TK_ID
    | primary
    ;

primary
    : TK_ID
    | TK_NUM
    | TK_REAL
    | TK_STRING
    | TK_LPAREN expr TK_RPAREN
    | allocate_expr
    ;

allocate_expr
    : TK_ALLOCATE TK_LPAREN expr TK_RPAREN
    ;

arg_list
    : arg_list TK_COMMA expr
    | expr
    ;

%%

/* ---------------------------------------------------------- */
/* Funções auxiliares                                          */
/* ---------------------------------------------------------- */

void yyerror(const char *msg) {
    fprintf(stderr, "[ERRO SINTATICO] linha %d: %s (token: '%s')\n", 
            yylineno, msg, yytext);
}

int main(void) {
    printf("=== GeoLang Parser ===\n");
    int result = yyparse();
    if (result == 0) {
        printf("=== Analise sintatica concluida com sucesso ===\n");
    }
    return result;
}