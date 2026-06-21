#include <stdio.h>
#include <assert.h>
#include <string.h>
#include "symbol_table.h"

static int tests_run = 0;
static int tests_passed = 0;

#define TEST(name) \
    do { \
        tests_run++; \
        printf("[TEST] %s ... ", name); \
    } while (0)

#define PASS() \
    do { \
        tests_passed++; \
        printf("OK\n"); \
    } while (0)

#define FAIL(msg) \
    do { \
        printf("FALHOU: %s\n", msg); \
    } while (0)

static void test_var_duplicate_same_scope(void) {
    TEST("variavel duplicada no mesmo escopo");

    VarScopeStack *stack = var_scope_stack_create();
    var_scope_push(stack);

    Type *t_int = type_create(TYPE_INT);
    bool first = var_insert(stack, "x", t_int, false, 1);

    Type *t_float = type_create(TYPE_FLOAT);
    bool second = var_insert(stack, "x", t_float, false, 2);

    if (first == true && second == false) {
        PASS();
    } else {
        FAIL("esperava primeira insercao=true, segunda=false");
    }

    type_destroy(t_float);
    var_scope_stack_destroy(stack);
}

static void test_var_distinct_non_nested_scopes(void) {
    TEST("variaveis em escopos distintos nao-aninhados");

    VarScopeStack *stack = var_scope_stack_create();
    var_scope_push(stack);

    var_scope_push(stack);
    Type *t1 = type_create(TYPE_INT);
    var_insert(stack, "temp", t1, false, 5);
    var_scope_pop(stack);

    var_scope_push(stack);
    Type *t2 = type_create(TYPE_FLOAT);
    bool ok = var_insert(stack, "temp", t2, false, 10);
    VarEntry *found = var_lookup(stack, "temp");

    if (ok && found != NULL && found->type->kind == TYPE_FLOAT) {
        PASS();
    } else {
        FAIL("esperava reinsercao livre apos pop do escopo anterior");
    }

    var_scope_pop(stack);
    var_scope_stack_destroy(stack);
}

static void test_var_nested_scope_access(void) {
    TEST("acesso a variavel do escopo pai (aninhado)");

    VarScopeStack *stack = var_scope_stack_create();
    var_scope_push(stack);

    Type *t_n = type_create(TYPE_INT);
    var_insert(stack, "n", t_n, false, 1);

    var_scope_push(stack);
    VarEntry *found = var_lookup(stack, "n");

    if (found != NULL && found->type->kind == TYPE_INT) {
        PASS();
    } else {
        FAIL("esperava encontrar 'n' subindo para o escopo pai");
    }

    var_scope_pop(stack);
    var_scope_pop(stack);
    var_scope_stack_destroy(stack);
}

static void test_var_not_declared(void) {
    TEST("variavel nao declarada retorna NULL");

    VarScopeStack *stack = var_scope_stack_create();
    var_scope_push(stack);

    VarEntry *found = var_lookup(stack, "inexistente");

    if (found == NULL) {
        PASS();
    } else {
        FAIL("esperava NULL para variavel nunca declarada");
    }

    var_scope_pop(stack);
    var_scope_stack_destroy(stack);
}

static void test_var_shadowing(void) {
    TEST("shadowing de variavel em escopo interno");

    VarScopeStack *stack = var_scope_stack_create();
    var_scope_push(stack);

    Type *t_outer = type_create(TYPE_INT);
    var_insert(stack, "x", t_outer, false, 1);

    var_scope_push(stack);
    Type *t_inner = type_create(TYPE_STRING);
    bool ok = var_insert(stack, "x", t_inner, false, 2);
    VarEntry *found = var_lookup(stack, "x");

    if (ok && found != NULL && found->type->kind == TYPE_STRING) {
        PASS();
    } else {
        FAIL("esperava que o escopo interno sobrepusesse o externo");
    }

    var_scope_pop(stack);
    found = var_lookup(stack, "x");

    if (found != NULL && found->type->kind == TYPE_INT) {
        printf("(verificacao extra: pai restaurado apos pop) OK\n");
    } else {
        printf("(verificacao extra: pai restaurado apos pop) FALHOU\n");
    }

    var_scope_pop(stack);
    var_scope_stack_destroy(stack);
}

static void test_struct_duplicate(void) {
    TEST("struct duplicada deve falhar");

    StructTable *table = struct_table_create();
    bool first = struct_insert(table, "Grafo", 1);
    bool second = struct_insert(table, "Grafo", 5);

    if (first == true && second == false) {
        PASS();
    } else {
        FAIL("esperava primeira=true, segunda=false");
    }

    struct_table_destroy(table);
}

static void test_struct_fields(void) {
    TEST("adicao e busca de campos de struct");

    StructTable *table = struct_table_create();
    struct_insert(table, "Ponto3D", 1);

    Type *t_x = type_create(TYPE_FLOAT);
    Type *t_y = type_create(TYPE_FLOAT);
    struct_add_field(table, "Ponto3D", "x", t_x);
    struct_add_field(table, "Ponto3D", "y", t_y);

    Type *t_x_dup = type_create(TYPE_FLOAT);
    bool dup_ok = struct_add_field(table, "Ponto3D", "x", t_x_dup);

    StructEntry *entry = struct_lookup(table, "Ponto3D");
    StructField *field_x = struct_field_lookup(entry, "x");
    StructField *field_z = struct_field_lookup(entry, "z");

    if (dup_ok == false && field_x != NULL && field_z == NULL) {
        PASS();
    } else {
        FAIL("esperava duplicidade bloqueada e busca de campo correta");
    }

    type_destroy(t_x_dup);
    struct_table_destroy(table);
}

static void test_func_duplicate_and_params(void) {
    TEST("funcao duplicada e ordem de parametros");

    FuncTable *table = func_table_create();
    Type *ret_int = type_create(TYPE_INT);
    bool first = func_insert(table, "partition", ret_int, 5);

    Type *ret_int2 = type_create(TYPE_INT);
    bool second = func_insert(table, "partition", ret_int2, 20);

    Type *t_arr = type_create_array(type_create(TYPE_FLOAT));
    Type *t_low = type_create(TYPE_INT);
    Type *t_high = type_create(TYPE_INT);

    func_add_param(table, "partition", "arr", t_arr, true);
    func_add_param(table, "partition", "low", t_low, false);
    func_add_param(table, "partition", "high", t_high, false);

    FuncEntry *entry = func_lookup(table, "partition");

    bool params_ok = false;
    if (entry != NULL && entry->param_count == 3) {
        ParamInfo *p = entry->params;
        params_ok = (strcmp(p->name, "arr") == 0 && p->is_mut == true);
        p = p->next;
        params_ok = params_ok && (strcmp(p->name, "low") == 0);
        p = p->next;
        params_ok = params_ok && (strcmp(p->name, "high") == 0);
    }

    if (first == true && second == false && params_ok) {
        PASS();
    } else {
        FAIL("esperava duplicidade bloqueada e parametros na ordem correta");
    }

    type_destroy(ret_int2);
    func_table_destroy(table);
}

static void test_type_equivalence(void) {
    TEST("equivalencia nominal de tipos");

    Type *int_a = type_create(TYPE_INT);
    Type *int_b = type_create(TYPE_INT);
    Type *float_a = type_create(TYPE_FLOAT);

    Type *struct_a = type_create_struct("Grafo");
    Type *struct_b = type_create_struct("Grafo");
    Type *struct_c = type_create_struct("QuadTree");

    Type *arr_float_a = type_create_array(type_create(TYPE_FLOAT));
    Type *arr_float_b = type_create_array(type_create(TYPE_FLOAT));
    Type *arr_int = type_create_array(type_create(TYPE_INT));

    bool ok = type_equals(int_a, int_b)
            && !type_equals(int_a, float_a)
            && type_equals(struct_a, struct_b)
            && !type_equals(struct_a, struct_c)
            && type_equals(arr_float_a, arr_float_b)
            && !type_equals(arr_float_a, arr_int);

    if (ok) {
        PASS();
    } else {
        FAIL("equivalencia de tipos incorreta");
    }

    type_destroy(int_a);
    type_destroy(int_b);
    type_destroy(float_a);
    type_destroy(struct_a);
    type_destroy(struct_b);
    type_destroy(struct_c);
    type_destroy(arr_float_a);
    type_destroy(arr_float_b);
    type_destroy(arr_int);
}

static void test_type_assignable_widening(void) {
    TEST("type_assignable permite widening int->float");

    Type *t_int = type_create(TYPE_INT);
    Type *t_float = type_create(TYPE_FLOAT);

    bool ok = type_assignable(t_float, t_int)
            && type_requires_widening(t_float, t_int);

    if (ok) {
        PASS();
    } else {
        FAIL("esperava widening int->float permitido");
    }

    type_destroy(t_int);
    type_destroy(t_float);
}

static void test_type_assignable_narrowing_blocked(void) {
    TEST("type_assignable bloqueia narrowing float->int");

    Type *t_int = type_create(TYPE_INT);
    Type *t_float = type_create(TYPE_FLOAT);

    bool ok = !type_assignable(t_int, t_float)
            && !type_requires_widening(t_int, t_float);

    if (ok) {
        PASS();
    } else {
        FAIL("esperava narrowing float->int bloqueado");
    }

    type_destroy(t_int);
    type_destroy(t_float);
}

static void test_type_assignable_identical(void) {
    TEST("type_assignable permite tipos identicos");

    Type *a = type_create(TYPE_STRING);
    Type *b = type_create(TYPE_STRING);

    if (type_assignable(a, b)) {
        PASS();
    } else {
        FAIL("esperava tipos identicos compativeis");
    }

    type_destroy(a);
    type_destroy(b);
}

static void test_type_assignable_geometric_blocked(void) {
    TEST("type_assignable bloqueia coercao entre tipos geometricos");

    Type *point = type_create(TYPE_POINT);
    Type *line = type_create(TYPE_LINE);

    if (!type_assignable(point, line)) {
        PASS();
    } else {
        FAIL("esperava Point e Line incompativeis (sem coercao implicita)");
    }

    type_destroy(point);
    type_destroy(line);
}

static void test_type_assignable_array_unknown_element(void) {
    TEST("type_assignable aceita array com elemento UNKNOWN (allocate)");

    Type *declared = type_create_array(type_create(TYPE_FLOAT));
    Type *from_allocate = type_create_array(type_create(TYPE_UNKNOWN));

    bool ok = type_assignable(declared, from_allocate);

    if (ok) {
        PASS();
    } else {
        FAIL("esperava [float] compativel com [unknown] vindo de allocate()");
    }

    type_destroy(declared);
    type_destroy(from_allocate);
}

static void test_type_assignable_array_mismatched_element_blocked(void) {
    TEST("type_assignable bloqueia array com elementos de tipo diferente");

    Type *arr_float = type_create_array(type_create(TYPE_FLOAT));
    Type *arr_int = type_create_array(type_create(TYPE_INT));

    if (!type_assignable(arr_float, arr_int)) {
        PASS();
    } else {
        FAIL("esperava [int] incompativel com [float] (sem widening em array)");
    }

    type_destroy(arr_float);
    type_destroy(arr_int);
}

int main(void) {
    printf("=== Testes da Tabela de Simbolos (GeoLang) ===\n\n");

    test_var_duplicate_same_scope();
    test_var_distinct_non_nested_scopes();
    test_var_nested_scope_access();
    test_var_not_declared();
    test_var_shadowing();
    test_struct_duplicate();
    test_struct_fields();
    test_func_duplicate_and_params();
    test_type_equivalence();
    test_type_assignable_widening();
    test_type_assignable_narrowing_blocked();
    test_type_assignable_identical();
    test_type_assignable_geometric_blocked();
    test_type_assignable_array_unknown_element();
    test_type_assignable_array_mismatched_element_blocked();

    printf("\n=== Resultado: %d/%d testes passaram ===\n",
           tests_passed, tests_run);

    return (tests_passed == tests_run) ? 0 : 1;
}