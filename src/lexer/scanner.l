%option yylineno noinput nounput
%{
    #include "../parser/parser.tab.h"
%}
%%
fn          { return TK_FN; }
var         { return TK_VAR; }
if          { return TK_IF; }
for         { return TK_FOR; }
while       { return TK_WHILE; }
do          { return TK_DO; }
else        { return TK_ELSE; }
elseif      { return TK_ELSEIF; }
return      { return TK_RETURN; }
in          { return TK_IN; }
allocate    { return TK_ALLOCATE; }
void        { return TK_VOID; }
int         { return TK_INT; }
float       { return TK_FLOAT; }
mut         { return TK_MUT; }
struct      { return TK_STRUCT; }
bool        { return TK_BOOL; }
string      { return TK_STRING; }
Point       { return TK_POINT; }
Line        { return TK_LINE; }
Polygon     { return TK_POLYGON; }
matrix      { return TK_MATRIX; }

"=="        { return TK_EQ; }
"!="        { return TK_NEQ; }
">="        { return TK_GEQ; }
"<="        { return TK_LEQ; }
">"         { return TK_GREATER; }
"<"         { return TK_LESS; }
"="         { return TK_ASSIGN; }
"+"         { return TK_SUM; }
"-"         { return TK_MIN; }
"*"         { return TK_MUL; }
"/"         { return TK_DIV; }
"->"        { return TK_ARROW; }
".."        { return TK_RANGE; }

";"         { return TK_SEMI; }
":"         { return TK_COLON; }
","         { return TK_COMMA; }
"."         { return TK_DOT; }
"("         { return TK_LPAREN; }
")"         { return TK_RPAREN; }
"{"         { return TK_LCURLY; }
"}"         { return TK_RCURLY; }
"["         { return TK_LBRACK; }
"]"         { return TK_RBRACK; }

[0-9]+"."[0-9]+         { return TK_REAL; }
[0-9]+                  { return TK_NUM; }
[a-zA-Z_][a-zA-Z0-9_]* { return TK_ID; }
\"([^\\\"]|\\.)*\"      { return TK_STRING; }

[ \t\n\r]+              { /* ignora espaço */ }
"//"[^\n]*              { /* ignora comentário */ }
.                       { printf("Erro léxico: caractere desconhecido '%s'\n", yytext); }
%%

int yywrap(void) { return 1; }