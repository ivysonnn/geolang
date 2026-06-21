#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <stdbool.h>

#define HASH_SIZE 211

typedef enum {
    TYPE_INT,
    TYPE_FLOAT,
    TYPE_BOOL,
    TYPE_STRING,
    TYPE_VOID,
    TYPE_POINT,
    TYPE_LINE,
    TYPE_POLYGON,
    TYPE_MATRIX,
    TYPE_ARRAY,
    TYPE_STRUCT,
    TYPE_UNKNOWN
} TypeKind;

typedef struct Type {
    TypeKind kind;
    struct Type *element_type;
    char *struct_name;
} Type;

Type *type_create(TypeKind kind);
Type *type_create_array(Type *element_type);
Type *type_create_struct(const char *struct_name);
Type *type_clone(const Type *type);
void  type_destroy(Type *type);
bool  type_equals(const Type *a, const Type *b);
const char *type_to_string(const Type *type);

/* ============================================================ */
/* Compatibilidade e coerção de tipos                            */
/* ============================================================ */

/* Verifica se 'from' pode ser atribuído a uma variável do tipo   */
/* 'to' SEM qualquer coerção (tipos idênticos). Usada como base    */
/* para type_assignable.                                            */
bool type_is_numeric(const Type *t);

/* Retorna true se a coerção implícita de 'from' para 'to' é       */
/* permitida pelas regras da GeoLang:                               */
/*   - tipos idênticos: sempre permitido;                           */
/*   - widening numerico (int -> float): permitido apenas para      */
/*     escalares simples, NAO se propaga dentro de arranjos;        */
/*   - narrowing (float -> int): NUNCA permitido;                   */
/*   - tipos geometricos/struct: NUNCA tem coercao implicita.        */
bool type_assignable(const Type *to, const Type *from);

/* Indica se a coerção exigiu widening (para fins de relatório/     */
/* depuração da gramática de atributos: "operação para               */
/* compatibilização de tipos").                                      */
bool type_requires_widening(const Type *to, const Type *from);

typedef struct VarEntry {
    char *name;
    Type *type;
    bool is_mut;
    int  line;
    struct VarEntry *next;
} VarEntry;

typedef struct VarScope {
    VarEntry *buckets[HASH_SIZE];
    struct VarScope *parent;
} VarScope;

typedef struct VarScopeStack {
    VarScope *top;
} VarScopeStack;

VarScopeStack *var_scope_stack_create(void);
void var_scope_stack_destroy(VarScopeStack *stack);
void var_scope_push(VarScopeStack *stack);
void var_scope_pop(VarScopeStack *stack);
bool var_insert(VarScopeStack *stack, const char *name, Type *type,
                 bool is_mut, int line);
VarEntry *var_lookup(VarScopeStack *stack, const char *name);
VarEntry *var_lookup_current_scope(VarScopeStack *stack, const char *name);

typedef struct StructField {
    char *name;
    Type *type;
    struct StructField *next;
} StructField;

typedef struct StructEntry {
    char *name;
    StructField *fields;
    int line;
    struct StructEntry *next;
} StructEntry;

typedef struct StructTable {
    StructEntry *buckets[HASH_SIZE];
} StructTable;

StructTable *struct_table_create(void);
void struct_table_destroy(StructTable *table);
bool struct_insert(StructTable *table, const char *name, int line);
bool struct_add_field(StructTable *table, const char *struct_name,
                       const char *field_name, Type *field_type);
StructEntry *struct_lookup(StructTable *table, const char *name);
StructField *struct_field_lookup(StructEntry *entry, const char *field_name);

typedef struct ParamInfo {
    char *name;
    Type *type;
    bool is_mut;
    struct ParamInfo *next;
} ParamInfo;

typedef struct FuncEntry {
    char *name;
    Type *return_type;
    ParamInfo *params;
    int param_count;
    int line;
    struct FuncEntry *next;
} FuncEntry;

typedef struct FuncTable {
    FuncEntry *buckets[HASH_SIZE];
} FuncTable;

FuncTable *func_table_create(void);
void func_table_destroy(FuncTable *table);
bool func_insert(FuncTable *table, const char *name, Type *return_type,
                  int line);
bool func_add_param(FuncTable *table, const char *func_name,
                     const char *param_name, Type *param_type, bool is_mut);
FuncEntry *func_lookup(FuncTable *table, const char *name);

#endif /* SYMBOL_TABLE_H */