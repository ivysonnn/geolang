%option yylineno noinput nounput
%{
    #include <string.h>
    #include "../parser/parser.tab.h"
%}
%%
fn          {printf("[DEBUG] TK_FN: '%s'\n", yytext); return TK_FN;}
var         {printf("[DEBUG] TK_VAR: '%s'\n", yytext); return TK_VAR;}
if          {printf("[DEBUG] TK_IF: '%s'\n", yytext); return TK_IF;}
for         {printf("[DEBUG] TK_FOR: '%s'\n", yytext); return TK_FOR;}
while       {printf("[DEBUG] TK_WHILE: '%s'\n", yytext); return TK_WHILE;}
do          {printf("[DEBUG] TK_DO: '%s'\n", yytext); return TK_DO;}
else        {printf("[DEBUG] TK_ELSE: '%s'\n", yytext); return TK_ELSE;}
elseif      {printf("[DEBUG] TK_ELSEIF: '%s'\n", yytext); return TK_ELSEIF;}
return      {printf("[DEBUG] TK_RETURN: '%s'\n", yytext); return TK_RETURN;}
in          {printf("[DEBUG] TK_IN: '%s'\n", yytext); return TK_IN;}
allocate    {printf("[DEBUG] TK_ALLOCATE: '%s'\n", yytext); return TK_ALLOCATE;}
void        {printf("[DEBUG] TK_VOID: '%s'\n", yytext); return TK_VOID;}
int         {printf("[DEBUG] TK_INT: '%s'\n", yytext); return TK_INT;}
float       {printf("[DEBUG] TK_FLOAT: '%s'\n", yytext); return TK_FLOAT;}
mut         {printf("[DEBUG] TK_MUT: '%s'\n", yytext); return TK_MUT;}
struct      {printf("[DEBUG] TK_STRUCT: '%s'\n", yytext); return TK_STRUCT;}
bool        {printf("[DEBUG] TK_BOOL: '%s'\n", yytext); return TK_BOOL;}
string      {printf("[DEBUG] TK_STRING: '%s'\n", yytext); return TK_STRING;}
true        {printf("[DEBUG] TK_TRUE: '%s'\n", yytext); return TK_TRUE;}
false       {printf("[DEBUG] TK_FALSE: '%s'\n", yytext); return TK_FALSE;}
Point       {printf("[DEBUG] TK_POINT: '%s'\n", yytext); return TK_POINT;}
Line        {printf("[DEBUG] TK_LINE: '%s'\n", yytext); return TK_LINE;}
Polygon     {printf("[DEBUG] TK_POLYGON: '%s'\n", yytext); return TK_POLYGON;}
matrix      {printf("[DEBUG] TK_MATRIX: '%s'\n", yytext); return TK_MATRIX;}

"==" {printf("[DEBUG] TK_EQ: '%s'\n", yytext); return TK_EQ;}
"!=" {printf("[DEBUG] TK_NEQ: '%s'\n", yytext); return TK_NEQ;}
">=" {printf("[DEBUG] TK_GEQ: '%s'\n", yytext); return TK_GEQ;}
"<=" {printf("[DEBUG] TK_LEQ: '%s'\n", yytext); return TK_LEQ;}
">"  {printf("[DEBUG] TK_GREATER: '%s'\n", yytext); return TK_GREATER;}
"<"  {printf("[DEBUG] TK_LESS: '%s'\n", yytext); return TK_LESS;}
"="  {printf("[DEBUG] TK_ASSIGN: '%s'\n", yytext); return TK_ASSIGN;}
"+"  {printf("[DEBUG] TK_SUM: '%s'\n", yytext); return TK_SUM;}
"-"  {printf("[DEBUG] TK_MIN: '%s'\n", yytext); return TK_MIN;}
"*"  {printf("[DEBUG] TK_MUL: '%s'\n", yytext); return TK_MUL;}
"/"  {printf("[DEBUG] TK_DIV: '%s'\n", yytext); return TK_DIV;}
";"  {printf("[DEBUG] TK_SEMI: '%s'\n", yytext); return TK_SEMI;}
":"  {printf("[DEBUG] TK_COLON: '%s'\n", yytext); return TK_COLON;}
"("  {printf("[DEBUG] TK_LPAREN: '%s'\n", yytext); return TK_LPAREN;}
")"  {printf("[DEBUG] TK_RPAREN: '%s'\n", yytext); return TK_RPAREN;}
"{"  {printf("[DEBUG] TK_LCURLY: '%s'\n", yytext); return TK_LCURLY;}
"}"  {printf("[DEBUG] TK_RCURLY: '%s'\n", yytext); return TK_RCURLY;}
"["  {printf("[DEBUG] TK_LBRACK: '%s'\n", yytext); return TK_LBRACK;}
"]"  {printf("[DEBUG] TK_RBRACK: '%s'\n", yytext); return TK_RBRACK;}
"."  {printf("[DEBUG] TK_DOT: '%s'\n", yytext); return TK_DOT;}
","  {printf("[DEBUG] TK_COMMA: '%s'\n", yytext); return TK_COMMA;}
"->" {printf("[DEBUG] TK_ARROW: '%s'\n", yytext); return TK_ARROW;}
".." {printf("[DEBUG] TK_RANGE: '%s'\n", yytext); return TK_RANGE;}

[0-9]+"."[0-9]+         {yylval.str = strdup(yytext); printf("[DEBUG] TK_REAL: '%s'\n", yytext); return TK_REAL;}
[0-9]+                  {yylval.str = strdup(yytext); printf("[DEBUG] TK_NUM: '%s'\n", yytext); return TK_NUM;}
[a-zA-Z_][a-zA-Z0-9_]*  {yylval.str = strdup(yytext); printf("[DEBUG] TK_ID: '%s'\n", yytext); return TK_ID;}
\"([^\\\"]|\\.)*\"      {yylval.str = strdup(yytext); printf("[DEBUG] TK_STRING: '%s'\n", yytext); return TK_STRING;}

[ \t\n\r]+          { /* nada */ }
"//"[^\n]*          { /* nada */ }
.                   { printf("Erro: caractere desconhecido '%s'\n", yytext); }
%%

int yywrap(void) { return 1; }