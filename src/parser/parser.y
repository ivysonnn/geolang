%code requires {
#include "../semantic/symbol_table.h"
#include "../codegen/strbuf.h"
#include "../codegen/label_gen.h"
}

%code {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

extern int  yylex(void);
extern char *yytext;
extern int  yylineno;

void yyerror(const char *msg);

/* ------------------------------------------------------------ */
/* Tabelas de símbolos globais do compilador                     */
/* ------------------------------------------------------------ */
VarScopeStack *g_vars    = NULL;  /* TABELA 1: variáveis (pilha)  */
StructTable   *g_structs = NULL;  /* TABELA 2: tipos de usuário    */
FuncTable     *g_funcs   = NULL;  /* TABELA 3: subprogramas        */

/* Buffer onde o código C reduzido (subconjunto do Anexo I) é        */
/* acumulado conforme as declarações de nível superior (funções e     */
/* structs) são reconhecidas. É emitido de uma só vez no final do      */
/* programa, após o relatório de erros léxicos/sintáticos/semânticos.   */
static StrBuf *g_code_output = NULL;

/* Nome da função sendo processada no momento (necessário para   */
/* registrar parâmetros na FuncTable durante a leitura da         */
/* lista de parâmetros).                                          */
static char *g_current_func_name = NULL;

/* Tipo de retorno declarado da função sendo processada no        */
/* momento. Usado para verificar se os 'return' do corpo são       */
/* compatíveis com a assinatura. NULL equivale a TYPE_VOID.        */
static Type *g_current_return_type = NULL;

/* Nome da struct sendo processada no momento (necessário para    */
/* registrar campos na StructTable durante a leitura dos campos). */
static char *g_current_struct_name = NULL;

/* Contador de erros semânticos para o resumo final.              */
static int g_semantic_errors = 0;

static void semantic_error(const char *fmt, ...);

/* Helper: cria uma cópia de tipo independente para ser armazenada */
/* em uma nova posição (evita duplo-free quando o mesmo Type* é     */
/* referenciado por múltiplas estruturas, ex: tipo de retorno        */
/* registrado tanto na FuncTable quanto em g_current_return_type).   */
static Type *dup_type(Type *t) { return type_clone(t); }

/* ------------------------------------------------------------ */
/* Tradução de tipos da GeoLang para os tipos de C reduzido.       */
/* Tipos geométricos (Point/Line/Polygon/matrix) e arranjos          */
/* sintetizam como ponteiros para float (matriz/vetor de floats),     */
/* conforme o documento de arquitetura ("abstrações geométricas       */
/* transpiladas para arranjos/matrizes numéricas").                    */
/* ------------------------------------------------------------ */
static char *c_type_name(const Type *t) {
    char *buf = (char *)malloc(64);
    if (t == NULL) { strcpy(buf, "void"); return buf; }
    switch (t->kind) {
        case TYPE_INT:     strcpy(buf, "int"); break;
        case TYPE_FLOAT:   strcpy(buf, "float"); break;
        case TYPE_BOOL:    strcpy(buf, "int"); break;
        case TYPE_STRING:  strcpy(buf, "char*"); break;
        case TYPE_VOID:    strcpy(buf, "void"); break;
        case TYPE_POINT:   strcpy(buf, "float*"); break;
        case TYPE_LINE:    strcpy(buf, "float*"); break;
        case TYPE_POLYGON: strcpy(buf, "float*"); break;
        case TYPE_MATRIX:  strcpy(buf, "float*"); break;
        case TYPE_ARRAY:   strcpy(buf, "float*"); break;
        case TYPE_STRUCT:
            snprintf(buf, 64, "struct %s", t->struct_name);
            break;
        default:           strcpy(buf, "int"); break;
    }
    return buf;
}


/* ------------------------------------------------------------ */
/* Lista encadeada de tipos, usada apenas durante o parsing de    */
/* listas de argumentos (arg_list) para verificação posicional     */
/* contra os parâmetros declarados da função chamada. Cada nó        */
/* também guarda o código C já traduzido daquele argumento, para      */
/* permitir montar a chamada de função reduzida "func(a, b, c)".       */
/* ------------------------------------------------------------ */
typedef struct TypeListNode {
    Type *type;
    char *code;
    struct TypeListNode *next;
} TypeListNode;

typedef struct TypeList {
    TypeListNode *head;
    TypeListNode *tail;
    int count;
} TypeList;

static TypeList *type_list_create(void) {
    TypeList *list = (TypeList *)malloc(sizeof(TypeList));
    list->head = NULL;
    list->tail = NULL;
    list->count = 0;
    return list;
}

static void type_list_append(TypeList *list, Type *type, char *code) {
    TypeListNode *node = (TypeListNode *)malloc(sizeof(TypeListNode));
    node->type = type;
    node->code = code;
    node->next = NULL;
    if (list->tail == NULL) {
        list->head = node;
    } else {
        list->tail->next = node;
    }
    list->tail = node;
    list->count++;
}

static void type_list_destroy(TypeList *list) {
    if (list == NULL) return;
    TypeListNode *node = list->head;
    while (node != NULL) {
        TypeListNode *next = node->next;
        type_destroy(node->type);
        free(node->code);
        free(node);
        node = next;
    }
    free(list);
}

/* Monta a string "a, b, c" com o código C de cada argumento,       */
/* na ordem original, para uso direto na chamada de função gerada.    */
static char *type_list_join_code(TypeList *list) {
    StrBuf *sb = strbuf_create();
    TypeListNode *node = list->head;
    bool first = true;
    while (node != NULL) {
        if (!first) strbuf_append(sb, ", ");
        strbuf_append(sb, node->code);
        first = false;
        node = node->next;
    }
    char *result = strbuf_dup_cstr(sb);
    strbuf_destroy(sb);
    return result;
}

/* Verifica a lista de argumentos de uma chamada contra os         */
/* parâmetros declarados da função, checando quantidade e            */
/* compatibilidade de tipo posição a posição.                        */
static void check_call_arguments(const char *func_name, TypeList *args) {
    FuncEntry *fe = func_lookup(g_funcs, func_name);
    if (fe == NULL) {
        /* já reportado como "funcao nao declarada" no chamador */
        return;
    }

    if (fe->param_count != args->count) {
        semantic_error(
            "funcao '%s' espera %d argumento(s), mas foi chamada com %d",
            func_name, fe->param_count, args->count);
        return;
    }

    ParamInfo *param = fe->params;
    TypeListNode *arg = args->head;
    int position = 1;
    while (param != NULL && arg != NULL) {
        if (!type_assignable(param->type, arg->type)) {
            semantic_error(
                "argumento %d de '%s' incompativel: "
                "esperado '%s', encontrado '%s'",
                position, func_name,
                type_to_string(param->type), type_to_string(arg->type));
        }
        param = param->next;
        arg = arg->next;
        position++;
    }
}

/* Helper: verifica que a condição de if/while/do-while é do tipo  */
/* bool, conforme a gramática de atributos da GeoLang exige.        */
static void check_condition_is_bool(Type *cond_type, const char *context) {
    if (cond_type != NULL && cond_type->kind != TYPE_BOOL
        && cond_type->kind != TYPE_UNKNOWN) {
        semantic_error(
            "condicao de '%s' deve ser do tipo bool, encontrado '%s'",
            context, type_to_string(cond_type));
    }
}

/* Helper: duplica uma string C simples (wrapper sobre strdup para   */
/* deixar explicito, nas acoes do parser, que estamos duplicando      */
/* fragmentos de codigo gerado, nao apenas identificadores).           */
static char *code_dup(const char *s) { return strdup(s); }

/* Helper: a função 'main' da GeoLang é declarada com retorno void     */
/* implícito, mas a convenção (e o padrão) da linguagem C exige que       */
/* 'main' retorne 'int'. Tratamos esse caso especialmente na emissão        */
/* de código para gerar 'int main(void) { ... return 0; }' em vez de         */
/* 'void main(void) { ... }', o que tornaria o C gerado não-portável.          */
static bool is_main_function(const char *name) {
    return strcmp(name, "main") == 0;
}

/* Helper: escolhe o especificador de formato de printf adequado    */
/* ao tipo real do argumento passado para io.print(...), evitando     */
/* o comportamento indefinido de usar sempre "%s" (que so e valido     */
/* para char*). Tipos geometricos/array (sintetizados como float*)      */
/* e structs nao tem uma representacao textual simples e usam "%p"       */
/* como fallback (imprime o endereco), documentado como limitacao.        */
static const char *printf_format_for_type(const Type *t) {
    if (t == NULL) return "%d";
    switch (t->kind) {
        case TYPE_INT:    return "%d";
        case TYPE_BOOL:   return "%d";
        case TYPE_FLOAT:  return "%f";
        case TYPE_STRING: return "%s";
        default:          return "%p";
    }
}

/* ------------------------------------------------------------ */
/* Atributo herdado do label de convergência final (Lend) de uma   */
/* cadeia if/elseif/else. O Bison/LALR(1) não suporta atributos       */
/* herdados nativamente entre regras já reduzidas (apenas atributos    */
/* sintetizados sobem na árvore); por isso usamos uma PILHA global       */
/* como "canal" para passar o Lend do if_stmt PARA dentro da               */
/* elseif_chain e do else_part antes de serem reduzidos — uma               */
/* técnica padrão em geradores LALR para simular herança de atributos.       */
/* A pilha (em vez de uma única variável) é necessária para suportar          */
/* if/elseif/else ANINHADOS: o Lend do if externo precisa ser preservado       */
/* enquanto o if interno (dentro do corpo de um dos ramos) usa e descarta       */
/* o seu próprio Lend.                                                            */
/* ------------------------------------------------------------ */
#define MAX_IF_NESTING 64
static char *g_if_chain_lend_stack[MAX_IF_NESTING];
static int   g_if_chain_lend_top = -1;

static void if_chain_lend_push(char *label) {
    g_if_chain_lend_top++;
    g_if_chain_lend_stack[g_if_chain_lend_top] = label;
}

static char *if_chain_lend_current(void) {
    return g_if_chain_lend_stack[g_if_chain_lend_top];
}

static void if_chain_lend_pop(void) {
    free(g_if_chain_lend_stack[g_if_chain_lend_top]);
    g_if_chain_lend_top--;
}
}

/* ---------------------------------------------------------- */
/* Union: valores semânticos transportados pelas regras        */
/* ---------------------------------------------------------- */
%union {
    char  *str;    /* texto de identificadores e literais       */
    Type  *type;   /* tipo construído (para 'type', etc)        */
    void  *arglist; /* TypeList* da lista de argumentos de chamada */
    struct {
        Type *type;  /* tipo sintetizado da expressão            */
        char *code;  /* fragmento de código C equivalente          */
    } expr;        /* expr/postfix_expr/primary/allocate_expr     */
    struct {
        char *name;
        Type *type;
        char *code;  /* fragmento de código C do lvalue (ex: "arr[i]") */
    } lval;        /* lvalue: nome + tipo resolvido + código        */
    struct {
        StrBuf *code; /* bloco de código C já traduzido            */
    } block;       /* stmt/stmt_list                               */
}

/* ---------------------------------------------------------- */
/* Declaração de tokens                                        */
/* ---------------------------------------------------------- */
%token <str> TK_ID TK_NUM TK_REAL TK_STRING

%token TK_INT TK_FLOAT TK_BOOL TK_VOID
%token TK_MUT TK_STRUCT
%token TK_POINT TK_LINE TK_POLYGON TK_MATRIX
%token TK_TRUE TK_FALSE

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

/* Tipos semânticos das regras não-terminais usadas no union */
%type <type> type ret_type
%type <expr> expr postfix_expr primary allocate_expr
%type <arglist> arg_list
%type <lval> lvalue
%type <str> param_list param
%type <block> stmt_list stmt var_decl assign_stmt if_stmt elseif_chain
%type <block> else_part for_stmt while_stmt do_while_stmt return_stmt
%type <block> expr_stmt

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

/* fn_header cuida do que é comum às duas formas de fn_decl:      */
/* registra a função na FuncTable e abre o escopo de variáveis     */
/* correspondente ao corpo da função (parâmetros entram aqui).     */
fn_header
    : TK_FN TK_ID TK_LPAREN
        {
            g_current_func_name = strdup($2);
            if (!func_insert(g_funcs, $2, NULL, yylineno)) {
                semantic_error(
                    "funcao '%s' ja declarada anteriormente", $2);
            }
            /* Escopo de variáveis do corpo da função. Parâmetros  */
            /* serão inseridos aqui mesmo, pela regra 'param'.     */
            var_scope_push(g_vars);
        }
    ;

fn_decl
    : fn_header param_list TK_RPAREN ret_type
        {
            g_current_return_type = dup_type($4);
            /* Atualiza o tipo de retorno já registrado na FuncTable  */
            /* (no momento de fn_header ainda não conhecíamos $4).    */
            FuncEntry *fe = func_lookup(g_funcs, g_current_func_name);
            if (fe != NULL) fe->return_type = dup_type($4);

            /* Emite a assinatura da função em C reduzido. */
            char *ret_c = c_type_name($4);
            strbuf_appendf(g_code_output, "%s %s(%s) {\n",
                            ret_c, g_current_func_name, (char *)$2);
            free(ret_c);
        }
      TK_LCURLY stmt_list TK_RCURLY
        {
            strbuf_append_buf(g_code_output, $7.code);
            strbuf_append(g_code_output, "}\n\n");
            strbuf_destroy($7.code);

            var_scope_pop(g_vars);
            free(g_current_func_name);
            g_current_func_name = NULL;
            type_destroy(g_current_return_type);
            g_current_return_type = NULL;
            free($2);
            printf("[PARSER] Funcao declarada com parametros\n");
        }
    | fn_header TK_RPAREN ret_type
        {
            g_current_return_type = dup_type($3);
            FuncEntry *fe = func_lookup(g_funcs, g_current_func_name);
            if (fe != NULL) fe->return_type = dup_type($3);

            char *ret_c = c_type_name($3);
            if (is_main_function(g_current_func_name)) {
                strbuf_append(g_code_output, "int main(void) {\n");
            } else {
                strbuf_appendf(g_code_output, "%s %s(void) {\n",
                                ret_c, g_current_func_name);
            }
            free(ret_c);
        }
      TK_LCURLY stmt_list TK_RCURLY
        {
            strbuf_append_buf(g_code_output, $6.code);
            if (is_main_function(g_current_func_name)) {
                strbuf_append(g_code_output, "return 0;\n");
            }
            strbuf_append(g_code_output, "}\n\n");
            strbuf_destroy($6.code);

            var_scope_pop(g_vars);
            free(g_current_func_name);
            g_current_func_name = NULL;
            type_destroy(g_current_return_type);
            g_current_return_type = NULL;
            printf("[PARSER] Funcao declarada sem parametros\n");
        }
    ;

ret_type
    : TK_ARROW type      { $$ = $2; }
    | TK_ARROW TK_VOID   { $$ = type_create(TYPE_VOID); }
    | /* vazio: retorno void implícito */
        { $$ = type_create(TYPE_VOID); }
    ;

/* ---------------------------------------------------------- */
/* Parâmetros                                                  */
/* ---------------------------------------------------------- */

/* param_list sintetiza a string C da lista de parâmetros, ex:     */
/* "float *arr, int low, int high", reaproveitando o slot          */
/* <str> da union (ela não precisa de tipo nem de bloco próprios). */
param_list
    : param_list TK_COMMA param
        {
            StrBuf *sb = strbuf_create();
            strbuf_append(sb, (char *)$1);
            strbuf_append(sb, ", ");
            strbuf_append(sb, (char *)$3);
            $$ = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            free($1);
            free($3);
        }
    | param
        { $$ = $1; }
    ;

/* Todo parâmetro é registrado em DOIS lugares:                  */
/*  (1) na FuncTable, como metadado da assinatura da função;      */
/*  (2) na VarScopeStack, para que o corpo da função possa usá-lo */
/*      como uma variável comum.                                   */
/* O parâmetro também sintetiza seu fragmento de assinatura em C,    */
/* ex: "float *arr" para 'arr: mut [float]'.                          */
param
    : TK_ID TK_COLON TK_MUT type
        {
            func_add_param(g_funcs, g_current_func_name, $1, $4, true);
            if (!var_insert(g_vars, $1, $4, true, yylineno)) {
                semantic_error(
                    "parametro '%s' duplicado na lista de parametros", $1);
            }
            printf("[PARSER] Parametro mut declarado: %s : mut %s\n",
                   $1, type_to_string($4));

            char *c_type = c_type_name($4);
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "%s %s", c_type, $1);
            $$ = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            free(c_type);
        }
    | TK_ID TK_COLON type
        {
            func_add_param(g_funcs, g_current_func_name, $1, $3, false);
            if (!var_insert(g_vars, $1, $3, false, yylineno)) {
                semantic_error(
                    "parametro '%s' duplicado na lista de parametros", $1);
            }
            printf("[PARSER] Parametro declarado: %s : %s\n",
                   $1, type_to_string($3));

            char *c_type = c_type_name($3);
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "%s %s", c_type, $1);
            $$ = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            free(c_type);
        }
    ;

/* ---------------------------------------------------------- */
/* Declaração de struct                                        */
/* ---------------------------------------------------------- */

struct_decl
    : TK_STRUCT TK_ID
        {
            g_current_struct_name = strdup($2);
            if (!struct_insert(g_structs, $2, yylineno)) {
                semantic_error("struct '%s' ja declarada anteriormente", $2);
            }
            strbuf_appendf(g_code_output, "struct %s {\n", $2);
        }
      TK_LCURLY field_list TK_RCURLY
        {
            strbuf_append(g_code_output, "};\n\n");
            printf("[PARSER] Struct declarada: %s\n", g_current_struct_name);
            free(g_current_struct_name);
            g_current_struct_name = NULL;
        }
    ;

field_list
    : field_list field
    | field
    ;

field
    : TK_ID TK_COLON type TK_SEMI
        {
            /* Bloqueia recursao direta de struct: um campo nao pode    */
            /* ter o mesmo tipo da struct que o contem, pois isso         */
            /* gera, na traducao para C, um campo de tipo incompleto        */
            /* (struct X { struct X campo; }; nao compila em C — o            */
            /* tamanho da struct dependeria de si mesma). Essa verificacao      */
            /* nao existia originalmente e foi adicionada apos um teste          */
            /* adversarial identificar que o compilador reportava "0 erros"       */
            /* semanticos para esse caso, mas o C gerado falhava ao compilar.      */
            if ($3->kind == TYPE_STRUCT
                && strcmp($3->struct_name, g_current_struct_name) == 0) {
                semantic_error(
                    "campo '%s' nao pode ter o mesmo tipo da struct '%s' "
                    "que o contem (recursao direta de tipo nao e permitida; "
                    "use um indice/identificador para modelar referencias "
                    "recursivas, como em um pool de nos)",
                    $1, g_current_struct_name);
            }

            if (!struct_add_field(g_structs, g_current_struct_name, $1, $3)) {
                semantic_error(
                    "campo '%s' duplicado na struct '%s'",
                    $1, g_current_struct_name);
            }
            char *c_type = c_type_name($3);
            strbuf_appendf(g_code_output, "    %s %s;\n", c_type, $1);
            free(c_type);
        }
    ;

/* ---------------------------------------------------------- */
/* Tipos                                                       */
/* ---------------------------------------------------------- */

type
    : TK_INT      { $$ = type_create(TYPE_INT); }
    | TK_FLOAT    { $$ = type_create(TYPE_FLOAT); }
    | TK_BOOL     { $$ = type_create(TYPE_BOOL); }
    | TK_STRING   { $$ = type_create(TYPE_STRING); }
    | TK_POINT    { $$ = type_create(TYPE_POINT); }
    | TK_LINE     { $$ = type_create(TYPE_LINE); }
    | TK_POLYGON  { $$ = type_create(TYPE_POLYGON); }
    | TK_MATRIX   { $$ = type_create(TYPE_MATRIX); }
    | TK_LBRACK type TK_RBRACK
        { $$ = type_create_array($2); }
    | TK_ID
        {
            if (struct_lookup(g_structs, $1) == NULL) {
                semantic_error("tipo '%s' nao foi declarado", $1);
            }
            $$ = type_create_struct($1);
        }
    ;

/* ---------------------------------------------------------- */
/* Statements                                                  */
/* ---------------------------------------------------------- */

stmt_list
    : stmt_list stmt
        {
            $$.code = strbuf_create();
            strbuf_append_buf($$.code, $1.code);
            strbuf_append_buf($$.code, $2.code);
            strbuf_destroy($1.code);
            strbuf_destroy($2.code);
        }
    | /* vazio */
        { $$.code = strbuf_create(); }
    ;

stmt
    : var_decl     { $$ = $1; }
    | assign_stmt  { $$ = $1; }
    | if_stmt      { $$ = $1; }
    | for_stmt     { $$ = $1; }
    | while_stmt   { $$ = $1; }
    | do_while_stmt { $$ = $1; }
    | return_stmt  { $$ = $1; }
    | expr_stmt    { $$ = $1; }
    ;

/* var x: tipo = expr; */
/* var x: tipo;        */
/* var x = expr;       */
var_decl
    : TK_VAR TK_ID TK_COLON type TK_ASSIGN expr TK_SEMI
        {
            if (!type_assignable($4, $6.type)) {
                semantic_error(
                    "tipo incompativel na declaracao de '%s': "
                    "esperado '%s', encontrado '%s'",
                    $2, type_to_string($4), type_to_string($6.type));
            } else if (type_requires_widening($4, $6.type)) {
                printf("[SEMANTICO] coercao implicita (widening) "
                       "int -> float na declaracao de '%s'\n", $2);
            }
            if (!var_insert(g_vars, $2, $4, false, yylineno)) {
                semantic_error(
                    "variavel '%s' ja declarada neste escopo", $2);
            }
            printf("[PARSER] Declaracao de variavel com tipo e valor: %s : %s\n",
                   $2, type_to_string($4));

            char *c_type = c_type_name($4);
            $$.code = strbuf_create();
            strbuf_appendf($$.code, "%s %s = %s;\n", c_type, $2, $6.code);
            free(c_type);

            type_destroy($6.type);
            free($6.code);
        }
    | TK_VAR TK_ID TK_COLON type TK_SEMI
        {
            if (!var_insert(g_vars, $2, $4, false, yylineno)) {
                semantic_error(
                    "variavel '%s' ja declarada neste escopo", $2);
            }
            printf("[PARSER] Declaracao de variavel com tipo: %s : %s\n",
                   $2, type_to_string($4));

            char *c_type = c_type_name($4);
            $$.code = strbuf_create();
            strbuf_appendf($$.code, "%s %s;\n", c_type, $2);
            free(c_type);
        }
    | TK_VAR TK_ID TK_ASSIGN expr TK_SEMI
        {
            /* Inferência de tipo: o tipo da variável é exatamente o */
            /* tipo sintetizado pela expressão do lado direito —      */
            /* um atributo sintetizado sendo copiado para a tabela     */
            /* de símbolos, exemplo direto de tradução dirigida pela    */
            /* sintaxe (ver documentação, secao sobre SDT).              */
            if (!var_insert(g_vars, $2, $4.type, false, yylineno)) {
                semantic_error(
                    "variavel '%s' ja declarada neste escopo", $2);
            }
            printf("[PARSER] Declaracao de variavel com inferencia: %s : %s\n",
                   $2, type_to_string($4.type));

            char *c_type = c_type_name($4.type);
            $$.code = strbuf_create();
            strbuf_appendf($$.code, "%s %s = %s;\n", c_type, $2, $4.code);
            free(c_type);
            free($4.code);
        }
    ;

assign_stmt
    : lvalue TK_ASSIGN expr TK_SEMI
        {
            if ($1.type != NULL) {
                if (!type_assignable($1.type, $3.type)) {
                    semantic_error(
                        "tipo incompativel na atribuicao a '%s': "
                        "esperado '%s', encontrado '%s'",
                        $1.name, type_to_string($1.type), type_to_string($3.type));
                } else if (type_requires_widening($1.type, $3.type)) {
                    printf("[SEMANTICO] coercao implicita (widening) "
                           "int -> float na atribuicao a '%s'\n", $1.name);
                }
            }
            printf("[PARSER] Atribuicao: %s\n", $1.name);

            $$.code = strbuf_create();
            strbuf_appendf($$.code, "%s = %s;\n", $1.code, $3.code);

            type_destroy($3.type);
            free($3.code);
            free($1.code);
        }
    ;

lvalue
    : TK_ID
        {
            VarEntry *entry = var_lookup(g_vars, $1);
            if (entry == NULL) {
                semantic_error("variavel '%s' nao foi declarada", $1);
                $$.type = NULL;
            } else {
                $$.type = entry->type;
            }
            $$.name = $1;
            $$.code = code_dup($1);
        }
    | TK_ID TK_LBRACK expr TK_RBRACK
        {
            VarEntry *entry = var_lookup(g_vars, $1);
            if (entry == NULL) {
                semantic_error("variavel '%s' nao foi declarada", $1);
                $$.type = NULL;
            } else if (entry->type->kind != TYPE_ARRAY) {
                semantic_error(
                    "'%s' nao e um arranjo, nao pode ser indexado", $1);
                $$.type = NULL;
            } else {
                if ($3.type->kind != TYPE_INT) {
                    semantic_error(
                        "indice de '%s' deve ser do tipo int, encontrado '%s'",
                        $1, type_to_string($3.type));
                }
                $$.type = entry->type->element_type;
            }
            $$.name = $1;

            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "%s[%s]", $1, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);

            type_destroy($3.type);
            free($3.code);
        }
    | TK_ID TK_DOT TK_ID
        {
            VarEntry *entry = var_lookup(g_vars, $1);
            if (entry == NULL) {
                semantic_error("variavel '%s' nao foi declarada", $1);
                $$.type = NULL;
            } else if (entry->type->kind != TYPE_STRUCT) {
                semantic_error(
                    "'%s' nao e uma struct, nao possui campos", $1);
                $$.type = NULL;
            } else {
                StructEntry *se = struct_lookup(g_structs, entry->type->struct_name);
                StructField *field = struct_field_lookup(se, $3);
                if (field == NULL) {
                    semantic_error(
                        "campo '%s' nao existe na struct '%s'",
                        $3, entry->type->struct_name);
                    $$.type = NULL;
                } else {
                    $$.type = field->type;
                }
            }
            $$.name = $1;

            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "%s.%s", $1, $3);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
        }
    ;

/* ---------------------------------------------------------- */
/* Estruturas de controle                                      */
/* ---------------------------------------------------------- */

/* Tradução de if/elseif/else para o C reduzido (apenas              */
/* 'if (cond) goto L;' e 'goto L;' são permitidos como comandos de    */
/* seleção, conforme o Anexo I). Cada ramo testado gera um par de       */
/* labels (verifica -> bloco) e todos os ramos convergem para um         */
/* único label final (Lend), que é gerado antes de qualquer ramo e        */
/* "herdado" via g_if_chain_lend pelos elseif/else subsequentes.           */
/*                                                                          */
/* Esquema gerado para "if c1 {A} elseif c2 {B} else {C}":                  */
/*   if (c1) goto Lthen0;                                                    */
/*   goto Lcheck1;                                                            */
/*   Lthen0: { A  goto Lend; }                                                */
/*   Lcheck1:                                                                  */
/*   if (c2) goto Lthen1;                                                      */
/*   goto Lelse;                                                                */
/*   Lthen1: { B  goto Lend; }                                                  */
/*   Lelse: { C }                                                                */
/*   Lend: ;                                                                      */
if_stmt
    : TK_IF
        {
            /* Gera o label de convergência ANTES de processar a       */
            /* condição e os ramos, e o empilha como atributo             */
            /* herdado para elseif_chain/else_part através da              */
            /* pilha global (ver nota acima sobre a limitação do            */
            /* Bison/LALR para herança direta de atributos).                 */
            if_chain_lend_push(label_gen_new());
        }
      expr
        { check_condition_is_bool($3.type, "if"); }
      TK_LCURLY
        { var_scope_push(g_vars); }
      stmt_list TK_RCURLY
        { var_scope_pop(g_vars); }
      elseif_chain else_part
        {
            printf("[PARSER] If-elseif-else\n");

            char *l_then = label_gen_new();
            char *l_next = label_gen_new();
            char *lend = if_chain_lend_current();

            $$.code = strbuf_create();
            strbuf_appendf($$.code, "if (%s) goto %s;\n", $3.code, l_then);
            strbuf_appendf($$.code, "goto %s;\n", l_next);
            strbuf_appendf($$.code, "%s: {\n", l_then);
            strbuf_append_buf($$.code, $7.code);
            strbuf_appendf($$.code, "goto %s;\n}\n", lend);
            strbuf_appendf($$.code, "%s:\n", l_next);

            /* elseif_chain ($10) já contém todos os pares de check/then */
            /* encadeados, terminando num "goto <label_else>" para o       */
            /* else_part (ou direto para Lend se não houver elseif).        */
            strbuf_append_buf($$.code, $10.code);

            /* else_part ($11) contém o bloco final (vazio se não houver   */
            /* 'else'), já delimitado por chaves quando presente.            */
            strbuf_append_buf($$.code, $11.code);

            strbuf_appendf($$.code, "%s: ;\n", lend);

            type_destroy($3.type);
            free($3.code);
            strbuf_destroy($7.code);
            strbuf_destroy($10.code);
            strbuf_destroy($11.code);
            free(l_then);
            free(l_next);
            if_chain_lend_pop();
        }
    ;

/* elseif_chain sintetiza a sequência de checagens encadeadas. Cada    */
/* elseif adicional gera seu próprio par (Lthen, Lnext) e termina         */
/* fazendo "goto g_if_chain_lend" ao final do seu bloco — convergindo      */
/* para o mesmo label final de todo o if/elseif/else.                       */
elseif_chain
    : elseif_chain TK_ELSEIF expr
        { check_condition_is_bool($3.type, "elseif"); }
      TK_LCURLY
        { var_scope_push(g_vars); }
      stmt_list TK_RCURLY
        {
            var_scope_pop(g_vars);

            char *l_then = label_gen_new();
            char *l_next = label_gen_new();
            char *lend = if_chain_lend_current();

            $$.code = strbuf_create();
            strbuf_append_buf($$.code, $1.code);
            strbuf_appendf($$.code, "if (%s) goto %s;\n", $3.code, l_then);
            strbuf_appendf($$.code, "goto %s;\n", l_next);
            strbuf_appendf($$.code, "%s: {\n", l_then);
            strbuf_append_buf($$.code, $7.code);
            strbuf_appendf($$.code, "goto %s;\n}\n", lend);
            strbuf_appendf($$.code, "%s:\n", l_next);

            type_destroy($3.type);
            free($3.code);
            strbuf_destroy($1.code);
            strbuf_destroy($7.code);
            free(l_then);
            free(l_next);
        }
    | /* vazio */
        { $$.code = strbuf_create(); }
    ;

else_part
    : TK_ELSE TK_LCURLY
        { var_scope_push(g_vars); }
      stmt_list TK_RCURLY
        {
            var_scope_pop(g_vars);
            $$.code = strbuf_create();
            strbuf_append(   $$.code, "{\n");
            strbuf_append_buf($$.code, $4.code);
            strbuf_append(   $$.code, "}\n");
            strbuf_destroy($4.code);
        }
    | /* vazio */
        { $$.code = strbuf_create(); }
    ;

/* Tradução de "for i in a..b { A }" para C reduzido (desaçucarado    */
/* como um laço controlado por goto, já que comandos de iteração         */
/* estruturados não são permitidos):                                       */
/*   int i = a;                                                              */
/*   Lstart:                                                                  */
/*   if (i < b) goto Lbody;                                                    */
/*   goto Lend;                                                                 */
/*   Lbody: { A  i = i + 1;  goto Lstart; }                                      */
/*   Lend: ;                                                                      */
for_stmt
    : TK_FOR TK_ID TK_IN expr TK_RANGE expr
        {
            if ($4.type->kind != TYPE_INT) {
                semantic_error(
                    "limite inicial do 'for' deve ser int, encontrado '%s'",
                    type_to_string($4.type));
            }
            if ($6.type->kind != TYPE_INT) {
                semantic_error(
                    "limite final do 'for' deve ser int, encontrado '%s'",
                    type_to_string($6.type));
            }
        }
      TK_LCURLY
        {
            var_scope_push(g_vars);
            /* A variável do laço 'i' pertence ao escopo do for.    */
            Type *t_int = type_create(TYPE_INT);
            var_insert(g_vars, $2, t_int, false, yylineno);
        }
      stmt_list TK_RCURLY
        {
            var_scope_pop(g_vars);
            printf("[PARSER] For-in range: %s\n", $2);

            char *l_start = label_gen_new();
            char *l_body  = label_gen_new();
            char *l_end   = label_gen_new();

            /* Todo o laço é envolvido em um bloco { } próprio para     */
            /* isolar o escopo da variável de iteração em C — caso        */
            /* contrário, dois 'for' consecutivos usando o mesmo nome       */
            /* de variável (ex: dois 'for i in ...') gerariam uma            */
            /* redeclaração inválida em C, já que C não tem escopos            */
            /* de bloco implícitos para variáveis fora de chaves.               */
            $$.code = strbuf_create();
            strbuf_append(   $$.code, "{\n");
            strbuf_appendf($$.code, "int %s = %s;\n", $2, $4.code);
            strbuf_appendf($$.code, "%s:\n", l_start);
            strbuf_appendf($$.code, "if (%s < %s) goto %s;\n",
                            $2, $6.code, l_body);
            strbuf_appendf($$.code, "goto %s;\n", l_end);
            strbuf_appendf($$.code, "%s: {\n", l_body);
            strbuf_append_buf($$.code, $10.code);
            strbuf_appendf($$.code, "%s = %s + 1;\n", $2, $2);
            strbuf_appendf($$.code, "goto %s;\n}\n", l_start);
            strbuf_appendf($$.code, "%s: ;\n", l_end);
            strbuf_append(   $$.code, "}\n");

            type_destroy($4.type);
            type_destroy($6.type);
            free($4.code);
            free($6.code);
            strbuf_destroy($10.code);
            free(l_start);
            free(l_body);
            free(l_end);
        }
    ;

/* Tradução de "while cond { A }" para C reduzido:                    */
/*   Lstart:                                                            */
/*   if (cond) goto Lbody;                                                */
/*   goto Lend;                                                             */
/*   Lbody: { A  goto Lstart; }                                              */
/*   Lend: ;                                                                  */
while_stmt
    : TK_WHILE expr
        { check_condition_is_bool($2.type, "while"); }
      TK_LCURLY
        { var_scope_push(g_vars); }
      stmt_list TK_RCURLY
        {
            var_scope_pop(g_vars);
            printf("[PARSER] While\n");

            char *l_start = label_gen_new();
            char *l_body  = label_gen_new();
            char *l_end   = label_gen_new();

            $$.code = strbuf_create();
            strbuf_appendf($$.code, "%s:\n", l_start);
            strbuf_appendf($$.code, "if (%s) goto %s;\n", $2.code, l_body);
            strbuf_appendf($$.code, "goto %s;\n", l_end);
            strbuf_appendf($$.code, "%s: {\n", l_body);
            strbuf_append_buf($$.code, $6.code);
            strbuf_appendf($$.code, "goto %s;\n}\n", l_start);
            strbuf_appendf($$.code, "%s: ;\n", l_end);

            type_destroy($2.type);
            free($2.code);
            strbuf_destroy($6.code);
            free(l_start);
            free(l_body);
            free(l_end);
        }
    ;

/* Tradução de "do { A } while cond;" para C reduzido. Mais simples    */
/* que while pois o corpo sempre executa ao menos uma vez, então não      */
/* precisa de salto de entrada — apenas testa a condição ao final e         */
/* decide se volta ao início do bloco:                                       */
/*   Lbody: { A }                                                              */
/*   if (cond) goto Lbody;                                                      */
do_while_stmt
    : TK_DO TK_LCURLY
        { var_scope_push(g_vars); }
      stmt_list TK_RCURLY TK_WHILE expr TK_SEMI
        {
            check_condition_is_bool($7.type, "do-while");
            var_scope_pop(g_vars);
            printf("[PARSER] Do-while\n");

            char *l_body = label_gen_new();

            $$.code = strbuf_create();
            strbuf_appendf($$.code, "%s: {\n", l_body);
            strbuf_append_buf($$.code, $4.code);
            strbuf_append(   $$.code, "}\n");
            strbuf_appendf($$.code, "if (%s) goto %s;\n", $7.code, l_body);

            type_destroy($7.type);
            free($7.code);
            strbuf_destroy($4.code);
            free(l_body);
        }
    ;

return_stmt
    : TK_RETURN expr TK_SEMI
        {
            if (g_current_return_type != NULL
                && g_current_return_type->kind == TYPE_VOID) {
                semantic_error(
                    "funcao '%s' e void, nao pode retornar valor",
                    g_current_func_name);
            } else if (g_current_return_type != NULL
                       && !type_assignable(g_current_return_type, $2.type)) {
                semantic_error(
                    "tipo de retorno incompativel em '%s': "
                    "esperado '%s', encontrado '%s'",
                    g_current_func_name,
                    type_to_string(g_current_return_type),
                    type_to_string($2.type));
            }
            printf("[PARSER] Return com valor\n");

            $$.code = strbuf_create();
            strbuf_appendf($$.code, "return %s;\n", $2.code);

            type_destroy($2.type);
            free($2.code);
        }
    | TK_RETURN TK_SEMI
        {
            if (g_current_return_type != NULL
                && g_current_return_type->kind != TYPE_VOID) {
                semantic_error(
                    "funcao '%s' espera retorno do tipo '%s', "
                    "mas 'return' nao retorna valor",
                    g_current_func_name,
                    type_to_string(g_current_return_type));
            }
            printf("[PARSER] Return void\n");

            $$.code = strbuf_create();
            strbuf_append($$.code, "return;\n");
        }
    ;

expr_stmt
    : expr TK_SEMI
        {
            $$.code = strbuf_create();
            strbuf_appendf($$.code, "%s;\n", $1.code);
            type_destroy($1.type);
            free($1.code);
        }
    ;

/* ---------------------------------------------------------- */
/* Expressões                                                  */
/* ---------------------------------------------------------- */

expr
    : expr TK_EQ  expr
        {
            /* Bloqueia '==' entre dois structs: embora type_equals       */
            /* considere dois structs do mesmo nome compatíveis (são o     */
            /* mesmo tipo nominal), o operador '==' do C nao e definido      */
            /* para tipos struct -- a traducao geraria C invalido. Para       */
            /* comparar conteudo de structs, a GeoLang exige uma funcao         */
            /* dedicada que compare campo a campo (ex: rational_igual no          */
            /* Problema 4), nao o operador '==' direto.                            */
            if ($1.type->kind == TYPE_STRUCT && $3.type->kind == TYPE_STRUCT) {
                semantic_error(
                    "operador '==' nao pode ser usado entre structs "
                    "('%s'); compare campo a campo atraves de uma funcao "
                    "dedicada", type_to_string($1.type));
            } else if (!type_equals($1.type, $3.type)
                && !(type_is_numeric($1.type) && type_is_numeric($3.type))) {
                semantic_error(
                    "operandos incompativeis em '==': '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
            }
            $$.type = type_create(TYPE_BOOL);
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s == %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | expr TK_NEQ expr
        {
            /* Mesma restricao de '==' acima, aplicada a '!='. */
            if ($1.type->kind == TYPE_STRUCT && $3.type->kind == TYPE_STRUCT) {
                semantic_error(
                    "operador '!=' nao pode ser usado entre structs "
                    "('%s'); compare campo a campo atraves de uma funcao "
                    "dedicada", type_to_string($1.type));
            } else if (!type_equals($1.type, $3.type)
                && !(type_is_numeric($1.type) && type_is_numeric($3.type))) {
                semantic_error(
                    "operandos incompativeis em '!=': '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
            }
            $$.type = type_create(TYPE_BOOL);
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s != %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | expr TK_LESS expr
        {
            if (!type_is_numeric($1.type) || !type_is_numeric($3.type)) {
                semantic_error(
                    "operador '<' exige operandos numericos, "
                    "encontrado '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
            }
            $$.type = type_create(TYPE_BOOL);
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s < %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | expr TK_GREATER expr
        {
            if (!type_is_numeric($1.type) || !type_is_numeric($3.type)) {
                semantic_error(
                    "operador '>' exige operandos numericos, "
                    "encontrado '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
            }
            $$.type = type_create(TYPE_BOOL);
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s > %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | expr TK_LEQ expr
        {
            if (!type_is_numeric($1.type) || !type_is_numeric($3.type)) {
                semantic_error(
                    "operador '<=' exige operandos numericos, "
                    "encontrado '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
            }
            $$.type = type_create(TYPE_BOOL);
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s <= %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | expr TK_GEQ expr
        {
            if (!type_is_numeric($1.type) || !type_is_numeric($3.type)) {
                semantic_error(
                    "operador '>=' exige operandos numericos, "
                    "encontrado '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
            }
            $$.type = type_create(TYPE_BOOL);
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s >= %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | expr TK_SUM expr
        {
            /* '+' tambem e usado para concatenacao de string no    */
            /* exemplo quicksort.geo ("texto" + (i+1) + "km"). Para   */
            /* nao travar esse uso idiomatico, permitimos string+    */
            /* qualquer escalar, resultando em string. A concatenacao  */
            /* real em C exigiria uma funcao de runtime (fora do        */
            /* escopo do C reduzido do Anexo I); por ora emitimos o       */
            /* operador '+' tambem nesse caso, documentado como             */
            /* limitacao (ver documentacao, secao de limitacoes).             */
            if (type_is_numeric($1.type) && type_is_numeric($3.type)) {
                $$.type = ($1.type->kind == TYPE_FLOAT || $3.type->kind == TYPE_FLOAT)
                     ? type_create(TYPE_FLOAT) : type_create(TYPE_INT);
            } else if ($1.type->kind == TYPE_STRING || $3.type->kind == TYPE_STRING) {
                $$.type = type_create(TYPE_STRING);
            } else {
                semantic_error(
                    "operandos incompativeis em '+': '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
                $$.type = type_create(TYPE_UNKNOWN);
            }
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s + %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | expr TK_MIN expr
        {
            if (!type_is_numeric($1.type) || !type_is_numeric($3.type)) {
                semantic_error(
                    "operador '-' exige operandos numericos, "
                    "encontrado '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
                $$.type = type_create(TYPE_UNKNOWN);
            } else {
                $$.type = ($1.type->kind == TYPE_FLOAT || $3.type->kind == TYPE_FLOAT)
                     ? type_create(TYPE_FLOAT) : type_create(TYPE_INT);
            }
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s - %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | expr TK_MUL expr
        {
            if (!type_is_numeric($1.type) || !type_is_numeric($3.type)) {
                semantic_error(
                    "operador '*' exige operandos numericos, "
                    "encontrado '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
                $$.type = type_create(TYPE_UNKNOWN);
            } else {
                $$.type = ($1.type->kind == TYPE_FLOAT || $3.type->kind == TYPE_FLOAT)
                     ? type_create(TYPE_FLOAT) : type_create(TYPE_INT);
            }
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s * %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | expr TK_DIV expr
        {
            if (!type_is_numeric($1.type) || !type_is_numeric($3.type)) {
                semantic_error(
                    "operador '/' exige operandos numericos, "
                    "encontrado '%s' e '%s'",
                    type_to_string($1.type), type_to_string($3.type));
                $$.type = type_create(TYPE_UNKNOWN);
            } else {
                $$.type = ($1.type->kind == TYPE_FLOAT || $3.type->kind == TYPE_FLOAT)
                     ? type_create(TYPE_FLOAT) : type_create(TYPE_INT);
            }
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s / %s)", $1.code, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($1.type); type_destroy($3.type);
            free($1.code); free($3.code);
        }
    | TK_MIN expr %prec UNARY_MINUS
        {
            if (!type_is_numeric($2.type)) {
                semantic_error(
                    "operador unario '-' exige operando numerico, "
                    "encontrado '%s'", type_to_string($2.type));
            }
            $$.type = $2.type;
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(-%s)", $2.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            free($2.code);
        }
    | postfix_expr
        { $$ = $1; }
    ;

postfix_expr
    /* arr[i] */
    : TK_ID TK_LBRACK expr TK_RBRACK
        {
            VarEntry *entry = var_lookup(g_vars, $1);
            if (entry == NULL) {
                semantic_error("variavel '%s' nao foi declarada", $1);
                $$.type = type_create(TYPE_UNKNOWN);
            } else if (entry->type->kind != TYPE_ARRAY) {
                semantic_error(
                    "'%s' nao e um arranjo, nao pode ser indexado", $1);
                $$.type = type_create(TYPE_UNKNOWN);
            } else {
                if ($3.type->kind != TYPE_INT) {
                    semantic_error(
                        "indice de '%s' deve ser do tipo int, encontrado '%s'",
                        $1, type_to_string($3.type));
                }
                $$.type = type_clone(entry->type->element_type);
            }
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "%s[%s]", $1, $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            type_destroy($3.type);
            free($3.code);
        }
    /* io.print(args) / io.read_int(args) / io.read_float(args) --   */
    /* chamadas qualificadas pelo namespace embutido 'io', traduzidas  */
    /* diretamente para as funções correspondentes da biblioteca C       */
    /* padrão (printf/scanf), conforme o documento de arquitetura         */
    /* ("Na transpilação para C, io.print(x) vira printf(...)").           */
    /* Por simplicidade, todo argumento é emitido como parâmetro de         */
    /* printf com formato genérico "%s" do C, deixando ao usuário a           */
    /* responsabilidade de adequar tipos em casos avançados — uma              */
    /* limitação documentada (ver seção de limitações).                          */
    | TK_ID TK_DOT TK_ID TK_LPAREN arg_list TK_RPAREN
        {
            TypeList *args = (TypeList *)$5;
            char *args_code = type_list_join_code(args);
            StrBuf *sb = strbuf_create();
            if (strcmp($3, "print") == 0) {
                /* Escolhe o formato de printf de acordo com o tipo     */
                /* real do primeiro (e, no uso atual da linguagem,        */
                /* unico) argumento, evitando o comportamento indefinido    */
                /* de assumir sempre char* (%s) para qualquer tipo.           */
                const char *fmt = (args->head != NULL)
                    ? printf_format_for_type(args->head->type)
                    : "%d";
                strbuf_appendf(sb, "printf(\"%s\\n\", %s)", fmt, args_code);
            } else if (strcmp($3, "read_int") == 0) {
                strbuf_appendf(sb, "geolang_read_int(%s)", args_code);
            } else if (strcmp($3, "read_float") == 0) {
                strbuf_appendf(sb, "geolang_read_float(%s)", args_code);
            } else {
                strbuf_appendf(sb, "%s_%s(%s)", $1, $3, args_code);
            }
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            free(args_code);
            $$.type = type_create(TYPE_UNKNOWN);
            type_list_destroy(args);
        }
    | TK_ID TK_DOT TK_ID TK_LPAREN TK_RPAREN
        {
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "%s_%s()", $1, $3);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            $$.type = type_create(TYPE_UNKNOWN);
        }
    /* func(args) */
    | TK_ID TK_LPAREN arg_list TK_RPAREN
        {
            FuncEntry *fe = func_lookup(g_funcs, $1);
            if (fe == NULL) {
                semantic_error("funcao '%s' nao foi declarada", $1);
                $$.type = type_create(TYPE_UNKNOWN);
            } else {
                check_call_arguments($1, (TypeList *)$3);
                $$.type = type_clone(fe->return_type);
            }
            char *args_code = type_list_join_code((TypeList *)$3);
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "%s(%s)", $1, args_code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            free(args_code);
            type_list_destroy((TypeList *)$3);
        }
    | TK_ID TK_LPAREN TK_RPAREN
        {
            FuncEntry *fe = func_lookup(g_funcs, $1);
            if (fe == NULL) {
                semantic_error("funcao '%s' nao foi declarada", $1);
                $$.type = type_create(TYPE_UNKNOWN);
            } else {
                if (fe->param_count != 0) {
                    semantic_error(
                        "funcao '%s' espera %d argumento(s), "
                        "mas foi chamada sem argumentos",
                        $1, fe->param_count);
                }
                $$.type = type_clone(fe->return_type);
            }
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "%s()", $1);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
        }
    /* acesso a campo: p.x */
    | TK_ID TK_DOT TK_ID
        {
            VarEntry *entry = var_lookup(g_vars, $1);
            if (entry == NULL) {
                semantic_error("variavel '%s' nao foi declarada", $1);
                $$.type = type_create(TYPE_UNKNOWN);
            } else if (entry->type->kind != TYPE_STRUCT) {
                semantic_error(
                    "'%s' nao e uma struct, nao possui campos", $1);
                $$.type = type_create(TYPE_UNKNOWN);
            } else {
                StructEntry *se = struct_lookup(g_structs, entry->type->struct_name);
                StructField *field = struct_field_lookup(se, $3);
                if (field == NULL) {
                    semantic_error(
                        "campo '%s' nao existe na struct '%s'",
                        $3, entry->type->struct_name);
                    $$.type = type_create(TYPE_UNKNOWN);
                } else {
                    $$.type = type_clone(field->type);
                }
            }
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "%s.%s", $1, $3);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
        }
    | primary
        { $$ = $1; }
    ;

primary
    : TK_ID
        {
            VarEntry *entry = var_lookup(g_vars, $1);
            if (entry == NULL) {
                semantic_error("variavel '%s' nao foi declarada", $1);
                $$.type = type_create(TYPE_UNKNOWN);
            } else {
                $$.type = type_clone(entry->type);
            }
            $$.code = code_dup($1);
        }
    | TK_NUM
        { $$.type = type_create(TYPE_INT); $$.code = code_dup($1); }
    | TK_REAL
        { $$.type = type_create(TYPE_FLOAT); $$.code = code_dup($1); }
    | TK_STRING
        { $$.type = type_create(TYPE_STRING); $$.code = code_dup($1); }
    | TK_TRUE
        { $$.type = type_create(TYPE_BOOL); $$.code = code_dup("1"); }
    | TK_FALSE
        { $$.type = type_create(TYPE_BOOL); $$.code = code_dup("0"); }
    | TK_LPAREN expr TK_RPAREN
        {
            StrBuf *sb = strbuf_create();
            strbuf_appendf(sb, "(%s)", $2.code);
            $$.type = $2.type;
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);
            free($2.code);
        }
    | allocate_expr
        { $$ = $1; }
    ;

/* allocate(n) é traduzido para uma chamada de malloc(), já que as     */
/* abstrações geométricas e arranjos da GeoLang sintetizam diretamente    */
/* para arranjos numéricos em C (conforme o documento de arquitetura).     */
/* O tipo do elemento é determinado pelo contexto de uso (a declaração       */
/* que recebe o allocate), então aqui emitimos apenas "malloc(n *               */
/* sizeof(...))" com um placeholder de tipo que é ajustado externamente         */
/* pela regra que consome esta expressão (ver var_decl).                          */
allocate_expr
    : TK_ALLOCATE TK_LPAREN expr TK_RPAREN
        {
            if ($3.type->kind != TYPE_INT) {
                semantic_error(
                    "allocate() exige um argumento do tipo int, "
                    "encontrado '%s'", type_to_string($3.type));
            }
            printf("[PARSER] Alocacao dinamica\n");
            /* allocate(n) produz um arranjo cujo tipo de elemento   */
            /* só é conhecido pelo contexto da declaração que o       */
            /* recebe (ex: var v: [float] = allocate(n)). Sintetiza-  */
            /* se aqui um arranjo de tipo de elemento desconhecido,    */
            /* e a checagem fina ocorre em var_decl via                */
            /* type_assignable, que trata TYPE_UNKNOWN como            */
            /* compatível em qualquer posição.                         */
            $$.type = type_create_array(type_create(TYPE_UNKNOWN));

            StrBuf *sb = strbuf_create();
            /* sizeof(float) é usado como tamanho padrão de elemento;  */
            /* refinamentos para outros tipos de elemento ficam como    */
            /* limitação documentada, já que o tipo real só é conhecido   */
            /* no momento da declaração que consome este allocate().      */
            strbuf_appendf(sb, "malloc(%s * sizeof(float))", $3.code);
            $$.code = strbuf_dup_cstr(sb);
            strbuf_destroy(sb);

            type_destroy($3.type);
            free($3.code);
        }
    ;

arg_list
    : arg_list TK_COMMA expr
        {
            TypeList *list = (TypeList *)$1;
            type_list_append(list, $3.type, $3.code);
            $$ = list;
        }
    | expr
        {
            TypeList *list = type_list_create();
            type_list_append(list, $1.type, $1.code);
            $$ = list;
        }
    ;

%%

/* ---------------------------------------------------------- */
/* Funções auxiliares                                          */
/* ---------------------------------------------------------- */

static void semantic_error(const char *fmt, ...) {
    g_semantic_errors++;
    fprintf(stderr, "[ERRO SEMANTICO] linha %d: ", yylineno);
    va_list args;
    va_start(args, fmt);
    vfprintf(stderr, fmt, args);
    va_end(args);
    fprintf(stderr, "\n");
}

void yyerror(const char *msg) {
    fprintf(stderr, "[ERRO SINTATICO] linha %d: %s (token: '%s')\n",
            yylineno, msg, yytext);
}

/* ------------------------------------------------------------ */
/* Suporte a escrita do código C gerado em arquivo.               */
/* O compilador continua lendo o programa GeoLang via stdin       */
/* (uso original, preservado por compatibilidade), mas agora        */
/* também aceita argumentos de linha de comando para controlar       */
/* onde o código C reduzido gerado é salvo em disco.                  */
/* ------------------------------------------------------------ */

#include <sys/stat.h>
#include <sys/types.h>
#include <libgen.h>

/* Cria o diretório (e pais, se necessário) caso não exista.       */
/* Equivalente a 'mkdir -p'. Ignora erro se o diretório já existe.   */
static void ensure_directory_exists(const char *path) {
    char tmp[1024];
    snprintf(tmp, sizeof(tmp), "%s", path);

    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(tmp, 0755);
            *p = '/';
        }
    }
    mkdir(tmp, 0755);
}

/* Deriva o nome base do arquivo .c de saída a partir do nome do    */
/* arquivo-fonte .geo informado (sem extensão), ou usa "out" como     */
/* padrão quando a entrada é stdin (sem nome de arquivo disponível).   */
static char *derive_output_filename(const char *input_path) {
    char *result = (char *)malloc(256);
    if (input_path == NULL) {
        strcpy(result, "out.c");
        return result;
    }

    char path_copy[512];
    snprintf(path_copy, sizeof(path_copy), "%s", input_path);
    char *base = basename(path_copy);

    /* Remove a extensão .geo (ou qualquer extensão) do nome base. */
    char *dot = strrchr(base, '.');
    if (dot != NULL) *dot = '\0';

    snprintf(result, 256, "%s.c", base);
    return result;
}

/* Preâmbulo emitido no início de todo arquivo C gerado: includes      */
/* padrão e pequenas funções de runtime que dão suporte às chamadas      */
/* io.read_int(...)/io.read_float(...) usadas pelos programas GeoLang,     */
/* já que o C reduzido do Anexo I não inclui leitura de entrada nativa      */
/* na linguagem fonte — a leitura é delegada a essas funções auxiliares,     */
/* implementadas com scanf() da biblioteca padrão de C. O parâmetro de        */
/* mensagem (prompt) é impresso antes da leitura, replicando a assinatura      */
/* esperada io.read_int("mensagem") / io.read_float("mensagem").                */
#define GEOLANG_RUNTIME_PREAMBLE \
    "#include <stdio.h>\n" \
    "#include <stdlib.h>\n" \
    "\n" \
    "static int geolang_read_int(const char *prompt) {\n" \
    "    int valor;\n" \
    "    printf(\"%s\", prompt);\n" \
    "    scanf(\"%d\", &valor);\n" \
    "    return valor;\n" \
    "}\n" \
    "\n" \
    "static float geolang_read_float(const char *prompt) {\n" \
    "    float valor;\n" \
    "    printf(\"%s\", prompt);\n" \
    "    scanf(\"%f\", &valor);\n" \
    "    return valor;\n" \
    "}\n" \
    "\n"

int main(int argc, char **argv) {
    /* Argumentos de linha de comando (todos opcionais):              */
    /*   argv[1]        -> caminho do arquivo .geo de entrada           */
    /*                     (se omitido, lê de stdin como antes)          */
    /*   -o <dir>       -> diretório onde o .c gerado deve ser salvo      */
    /*                     (padrão: "output")                              */
    const char *input_path = NULL;
    const char *output_dir = "output";

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
            output_dir = argv[i + 1];
            i++;
        } else {
            input_path = argv[i];
        }
    }

    FILE *input_stream = stdin;
    if (input_path != NULL) {
        input_stream = fopen(input_path, "r");
        if (input_stream == NULL) {
            fprintf(stderr, "Erro: nao foi possivel abrir o arquivo '%s'\n", input_path);
            return 1;
        }
        extern FILE *yyin;
        yyin = input_stream;
    }

    printf("=== GeoLang Parser + Analisador Semantico ===\n");

    g_vars    = var_scope_stack_create();
    g_structs = struct_table_create();
    g_funcs   = func_table_create();
    g_code_output = strbuf_create();
    label_gen_reset();

    /* Escopo global: variáveis declaradas fora de qualquer função   */
    /* (a GeoLang atual não usa isso no nível de programa, mas o      */
    /* escopo é mantido por consistência da pilha).                   */
    var_scope_push(g_vars);

    int result = yyparse();

    var_scope_pop(g_vars);
    var_scope_stack_destroy(g_vars);
    struct_table_destroy(g_structs);
    func_table_destroy(g_funcs);

    if (input_path != NULL) {
        fclose(input_stream);
    }

    if (result == 0 && g_semantic_errors == 0) {
        printf("=== Analise concluida com sucesso (0 erros semanticos) ===\n");
        printf("\n=== Codigo C reduzido gerado ===\n");
        printf("%s", GEOLANG_RUNTIME_PREAMBLE);
        printf("%s", strbuf_cstr(g_code_output));

        /* Escreve o mesmo conteúdo em um arquivo .c dentro da pasta   */
        /* de saída configurada (padrão: "output/"), criando o            */
        /* diretório automaticamente caso ainda não exista.                */
        ensure_directory_exists(output_dir);

        char *out_filename = derive_output_filename(input_path);
        char out_path[768];
        snprintf(out_path, sizeof(out_path), "%s/%s", output_dir, out_filename);

        FILE *out_file = fopen(out_path, "w");
        if (out_file == NULL) {
            fprintf(stderr, "Aviso: nao foi possivel escrever o arquivo '%s'\n", out_path);
        } else {
            fprintf(out_file, "%s", GEOLANG_RUNTIME_PREAMBLE);
            fprintf(out_file, "%s", strbuf_cstr(g_code_output));
            fclose(out_file);
            printf("\n=== Codigo C salvo em: %s ===\n", out_path);
        }
        free(out_filename);

    } else if (result == 0) {
        printf("=== Analise sintatica OK, mas %d erro(s) semantico(s) encontrado(s) ===\n",
               g_semantic_errors);
        strbuf_destroy(g_code_output);
        return 1;
    }

    strbuf_destroy(g_code_output);

    return result;
}