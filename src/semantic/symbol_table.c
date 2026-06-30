#include "symbol_table.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned int hash_string(const char *str) {
    unsigned int hash = 0;
    while (*str) {
        hash = hash * 31 + (unsigned char)(*str);
        str++;
    }
    return hash % HASH_SIZE;
}

Type *type_create(TypeKind kind) {
    Type *t = (Type *)malloc(sizeof(Type));
    t->kind = kind;
    t->element_type = NULL;
    t->struct_name = NULL;
    return t;
}

Type *type_create_array(Type *element_type) {
    Type *t = type_create(TYPE_ARRAY);
    t->element_type = element_type;
    return t;
}

Type *type_create_struct(const char *struct_name) {
    Type *t = type_create(TYPE_STRUCT);
    t->struct_name = strdup(struct_name);
    return t;
}

void type_destroy(Type *type) {
    if (type == NULL) return;
    if (type->element_type != NULL) {
        type_destroy(type->element_type);
    }
    if (type->struct_name != NULL) {
        free(type->struct_name);
    }
    free(type);
}

bool type_equals(const Type *a, const Type *b) {
    if (a == NULL || b == NULL) return false;
    if (a->kind != b->kind) return false;

    if (a->kind == TYPE_ARRAY) {
        return type_equals(a->element_type, b->element_type);
    }
    if (a->kind == TYPE_STRUCT) {
        return strcmp(a->struct_name, b->struct_name) == 0;
    }
    return true;
}

const char *type_to_string(const Type *type) {
    static char buffer[256];
    if (type == NULL) return "unknown";

    switch (type->kind) {
        case TYPE_INT:     return "int";
        case TYPE_FLOAT:   return "float";
        case TYPE_BOOL:    return "bool";
        case TYPE_STRING:  return "string";
        case TYPE_VOID:    return "void";
        case TYPE_POINT:   return "Point";
        case TYPE_LINE:    return "Line";
        case TYPE_POLYGON: return "Polygon";
        case TYPE_MATRIX:  return "matrix";
        case TYPE_ARRAY:
            snprintf(buffer, sizeof(buffer), "[%s]",
                      type_to_string(type->element_type));
            return buffer;
        case TYPE_STRUCT:
            return type->struct_name;
        default:
            return "unknown";
    }
}

Type *type_clone(const Type *type) {
    if (type == NULL) return NULL;

    Type *clone = type_create(type->kind);
    if (type->kind == TYPE_ARRAY) {
        clone->element_type = type_clone(type->element_type);
    }
    if (type->kind == TYPE_STRUCT) {
        clone->struct_name = strdup(type->struct_name);
    }
    return clone;
}

/* ============================================================ */
/* Compatibilidade e coerção de tipos                            */
/* ============================================================ */

bool type_is_numeric(const Type *t) {
    if (t == NULL) return false;
    return t->kind == TYPE_INT || t->kind == TYPE_FLOAT;
}

bool type_requires_widening(const Type *to, const Type *from) {
    if (to == NULL || from == NULL) return false;
    return from->kind == TYPE_INT && to->kind == TYPE_FLOAT;
}

bool type_assignable(const Type *to, const Type *from) {
    if (to == NULL || from == NULL) return false;

    /* TYPE_UNKNOWN é usado como placeholder de inferência ainda    */
    /* não resolvida (ex: retorno de allocate(), cujo tipo de        */
    /* elemento só é conhecido pelo contexto da declaração que o      */
    /* recebe); tratamos como compatível para não disparar falsos      */
    /* positivos em cascata.                                            */
    if (to->kind == TYPE_UNKNOWN || from->kind == TYPE_UNKNOWN) {
        return true;
    }

    /* Caso especial: arranjos. A coerção de widening (int->float)     */
    /* é definida pela GeoLang apenas para escalares simples e NÃO      */
    /* se propaga para dentro de arranjos — um [int] não é               */
    /* automaticamente compatível com [float], pois isso exigiria        */
    /* uma conversão elemento a elemento em tempo de execução, o que       */
    /* contraria a filosofia de tipagem estática e zero-custo da          */
    /* linguagem. A única excecao e quando o tipo de elemento de um        */
    /* dos lados ainda é TYPE_UNKNOWN (resultado de allocate() sem         */
    /* contexto), tratado recursivamente abaixo.                            */
    if (to->kind == TYPE_ARRAY && from->kind == TYPE_ARRAY) {
        if (to->element_type->kind == TYPE_UNKNOWN
            || from->element_type->kind == TYPE_UNKNOWN) {
            return true;
        }
        return type_equals(to->element_type, from->element_type);
    }

    /* Tipos idênticos: sempre compatível (equivalência nominal       */
    /* para struct, estrutural para array, ver type_equals).          */
    if (type_equals(to, from)) {
        return true;
    }

    /* Único caso de coerção implícita permitido pela GeoLang:        */
    /* widening de int para float, válido apenas para escalares        */
    /* simples (não dentro de arranjos, ver acima). Narrowing           */
    /* (float -> int) e qualquer coerção envolvendo tipos                */
    /* geométricos ou struct são proibidas, conforme o documento          */
    /* de arquitetura.                                                     */
    if (type_requires_widening(to, from)) {
        return true;
    }

    return false;
}

static VarScope *var_scope_create(VarScope *parent) {
    VarScope *scope = (VarScope *)malloc(sizeof(VarScope));
    for (int i = 0; i < HASH_SIZE; i++) {
        scope->buckets[i] = NULL;
    }
    scope->parent = parent;
    return scope;
}

static void var_scope_destroy(VarScope *scope) {
    if (scope == NULL) return;
    for (int i = 0; i < HASH_SIZE; i++) {
        VarEntry *entry = scope->buckets[i];
        while (entry != NULL) {
            VarEntry *next = entry->next;
            free(entry->name);
            free(entry);
            entry = next;
        }
    }
    free(scope);
}

VarScopeStack *var_scope_stack_create(void) {
    VarScopeStack *stack = (VarScopeStack *)malloc(sizeof(VarScopeStack));
    stack->top = NULL;
    return stack;
}

void var_scope_stack_destroy(VarScopeStack *stack) {
    if (stack == NULL) return;
    while (stack->top != NULL) {
        var_scope_pop(stack);
    }
    free(stack);
}

void var_scope_push(VarScopeStack *stack) {
    VarScope *new_scope = var_scope_create(stack->top);
    stack->top = new_scope;
}

void var_scope_pop(VarScopeStack *stack) {
    if (stack->top == NULL) return;
    VarScope *old_top = stack->top;
    stack->top = old_top->parent;
    var_scope_destroy(old_top);
}

VarEntry *var_lookup_current_scope(VarScopeStack *stack, const char *name) {
    if (stack->top == NULL) return NULL;

    unsigned int index = hash_string(name);
    VarEntry *entry = stack->top->buckets[index];
    while (entry != NULL) {
        if (strcmp(entry->name, name) == 0) {
            return entry;
        }
        entry = entry->next;
    }
    return NULL;
}

bool var_insert(VarScopeStack *stack, const char *name, Type *type,
                 bool is_mut, int line) {
    if (stack->top == NULL) {
        return false;
    }

    if (var_lookup_current_scope(stack, name) != NULL) {
        return false;
    }

    unsigned int index = hash_string(name);
    VarEntry *entry = (VarEntry *)malloc(sizeof(VarEntry));
    entry->name = strdup(name);
    entry->type = type;
    entry->is_mut = is_mut;
    entry->line = line;
    entry->next = stack->top->buckets[index];
    stack->top->buckets[index] = entry;
    return true;
}

VarEntry *var_lookup(VarScopeStack *stack, const char *name) {
    unsigned int index = hash_string(name);
    VarScope *scope = stack->top;

    while (scope != NULL) {
        VarEntry *entry = scope->buckets[index];
        while (entry != NULL) {
            if (strcmp(entry->name, name) == 0) {
                return entry;
            }
            entry = entry->next;
        }
        scope = scope->parent;
    }
    return NULL;
}

StructTable *struct_table_create(void) {
    StructTable *table = (StructTable *)malloc(sizeof(StructTable));
    for (int i = 0; i < HASH_SIZE; i++) {
        table->buckets[i] = NULL;
    }
    return table;
}

static void struct_fields_destroy(StructField *field) {
    while (field != NULL) {
        StructField *next = field->next;
        free(field->name);
        free(field);
        field = next;
    }
}

void struct_table_destroy(StructTable *table) {
    if (table == NULL) return;
    for (int i = 0; i < HASH_SIZE; i++) {
        StructEntry *entry = table->buckets[i];
        while (entry != NULL) {
            StructEntry *next = entry->next;
            struct_fields_destroy(entry->fields);
            free(entry->name);
            free(entry);
            entry = next;
        }
    }
    free(table);
}

StructEntry *struct_lookup(StructTable *table, const char *name) {
    unsigned int index = hash_string(name);
    StructEntry *entry = table->buckets[index];
    while (entry != NULL) {
        if (strcmp(entry->name, name) == 0) {
            return entry;
        }
        entry = entry->next;
    }
    return NULL;
}

bool struct_insert(StructTable *table, const char *name, int line) {
    if (struct_lookup(table, name) != NULL) {
        return false;
    }

    unsigned int index = hash_string(name);
    StructEntry *entry = (StructEntry *)malloc(sizeof(StructEntry));
    entry->name = strdup(name);
    entry->fields = NULL;
    entry->line = line;
    entry->next = table->buckets[index];
    table->buckets[index] = entry;
    return true;
}

StructField *struct_field_lookup(StructEntry *entry, const char *field_name) {
    if (entry == NULL) return NULL;
    StructField *field = entry->fields;
    while (field != NULL) {
        if (strcmp(field->name, field_name) == 0) {
            return field;
        }
        field = field->next;
    }
    return NULL;
}

bool struct_add_field(StructTable *table, const char *struct_name,
                       const char *field_name, Type *field_type) {
    StructEntry *entry = struct_lookup(table, struct_name);
    if (entry == NULL) return false;

    if (struct_field_lookup(entry, field_name) != NULL) {
        return false;
    }

    StructField *field = (StructField *)malloc(sizeof(StructField));
    field->name = strdup(field_name);
    field->type = field_type;
    field->next = NULL;
    if (entry->fields == NULL) {
        entry->fields = field;
    } else {
        StructField *last = entry->fields;
        while (last->next != NULL) {
            last = last->next;
        }
        last->next = field;
    }
    return true;
}

FuncTable *func_table_create(void) {
    FuncTable *table = (FuncTable *)malloc(sizeof(FuncTable));
    for (int i = 0; i < HASH_SIZE; i++) {
        table->buckets[i] = NULL;
    }
    return table;
}

static void func_params_destroy(ParamInfo *param) {
    while (param != NULL) {
        ParamInfo *next = param->next;
        free(param->name);
        free(param);
        param = next;
    }
}

void func_table_destroy(FuncTable *table) {
    if (table == NULL) return;
    for (int i = 0; i < HASH_SIZE; i++) {
        FuncEntry *entry = table->buckets[i];
        while (entry != NULL) {
            FuncEntry *next = entry->next;
            func_params_destroy(entry->params);
            free(entry->name);
            free(entry);
            entry = next;
        }
    }
    free(table);
}

FuncEntry *func_lookup(FuncTable *table, const char *name) {
    unsigned int index = hash_string(name);
    FuncEntry *entry = table->buckets[index];
    while (entry != NULL) {
        if (strcmp(entry->name, name) == 0) {
            return entry;
        }
        entry = entry->next;
    }
    return NULL;
}

bool func_insert(FuncTable *table, const char *name, Type *return_type,
                  int line) {
    if (func_lookup(table, name) != NULL) {
        return false;
    }

    unsigned int index = hash_string(name);
    FuncEntry *entry = (FuncEntry *)malloc(sizeof(FuncEntry));
    entry->name = strdup(name);
    entry->return_type = return_type;
    entry->params = NULL;
    entry->param_count = 0;
    entry->line = line;
    entry->next = table->buckets[index];
    table->buckets[index] = entry;
    return true;
}

bool func_add_param(FuncTable *table, const char *func_name,
                     const char *param_name, Type *param_type, bool is_mut) {
    FuncEntry *entry = func_lookup(table, func_name);
    if (entry == NULL) return false;

    ParamInfo *param = (ParamInfo *)malloc(sizeof(ParamInfo));
    param->name = strdup(param_name);
    param->type = param_type;
    param->is_mut = is_mut;
    param->next = NULL;

    if (entry->params == NULL) {
        entry->params = param;
    } else {
        ParamInfo *last = entry->params;
        while (last->next != NULL) {
            last = last->next;
        }
        last->next = param;
    }
    entry->param_count++;
    return true;
}
