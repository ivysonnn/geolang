%{
    #include "tokens.h"
%}

%%
fn {return TK_FN;}
var {return TK_VAR;}
if {return TK_IF;}
for {return TK_FOR;}
while {return TK_WHILE;}
do {return TK_DO;}
else {return TK_ELSE;}
elseif {return TK_ELSEIF;}
return {return TK_RETURN;}
in {return TK_IN;}

"==" {return TK_EQ;}
"!=" {return TK_NEQ;}
">=" {return TK_GEQ;}
"<=" {return TK_LEQ;}
">" {return TK_GREATER;}
"<" {return TK_LESS;}
"=" {return TK_ASSIGN;}
"+" {return TK_SUM;}
"-" {return TK_MIN;}
"*" {return TK_MUL;}
"/" {return TK_DIV;}
";" {return TK_SEMI;}
":" {return TK_COLON;}
"(" {return TK_LPAREN;}
")" {return TK_RPAREN;}
"{" {return TK_LCURLY;}
"}" {return TK_RCURLY;}
"[" {return TK_LBRACK;}
"]" {return TK_RBRACK;}
"." {return TK_DOT;}
, {return TK_COMMA;}
-> {return TK_ARROW;}
".." {return TK_RANGE;}

([0-9]+"."[0-9]+) {return TK_REAL;}
([0-9]+) {return TK_NUM;}
[a-zA-Z_][a-zA-Z0-9_]* {return TK_ID;}
\"([^\\\"]|\\.)*\" {return TK_STRING;}
[ \t\n\r]+          { /* nada */ }
"//"[^\n]*          { /* nada */}
.                  { printf("Erro: caractere desconhecido %s\n", yytext); }
%%

#ifndef yywrap
int yywrap (void) {return 1;}
#endif

int main(void){
    int tok;
    while((tok = yylex()) != 0);
    return 0;
}
