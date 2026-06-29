#include <stdio.h>
#include <stdlib.h>

static int geolang_read_int(const char *prompt) {
    int valor;
    printf("%s", prompt);
    scanf("%d", &valor);
    return valor;
}

static float geolang_read_float(const char *prompt) {
    float valor;
    printf("%s", prompt);
    scanf("%f", &valor);
    return valor;
}

struct rational_t {
    int numerador;
    int denominador;
};

struct rational_t rational_criar(int a, int b) {
struct rational_t r;
r.numerador = a;
r.denominador = b;
return r;
}

int rational_igual(struct rational_t r1, struct rational_t r2) {
int igual = ((r1.numerador * r2.denominador) == (r2.numerador * r1.denominador));
return igual;
}

struct rational_t rational_soma(struct rational_t r1, struct rational_t r2) {
int num = ((r1.numerador * r2.denominador) + (r2.numerador * r1.denominador));
int den = (r1.denominador * r2.denominador);
return rational_criar(num, den);
}

struct rational_t rational_negacao(struct rational_t r) {
int num = (0 - r.numerador);
return rational_criar(num, r.denominador);
}

struct rational_t rational_subtracao(struct rational_t r1, struct rational_t r2) {
struct rational_t r2_neg = rational_negacao(r2);
return rational_soma(r1, r2_neg);
}

struct rational_t rational_multiplicacao(struct rational_t r1, struct rational_t r2) {
int num = (r1.numerador * r2.numerador);
int den = (r1.denominador * r2.denominador);
return rational_criar(num, den);
}

struct rational_t rational_inverso(struct rational_t r) {
return rational_criar(r.denominador, r.numerador);
}

struct rational_t rational_divisao(struct rational_t r1, struct rational_t r2) {
struct rational_t r2_inv = rational_inverso(r2);
return rational_multiplicacao(r1, r2_inv);
}

int main(void) {
struct rational_t r1 = rational_criar(1, 2);
struct rational_t r2 = rational_criar(2, 4);
struct rational_t r3 = rational_criar(1, 3);
printf("%s\n", "r1 = 1/2, r2 = 2/4, r3 = 1/3");
int iguais_r1_r2 = rational_igual(r1, r2);
printf("%s\n", "r1 igual a r2 (esperado true):");
printf("%d\n", iguais_r1_r2);
int iguais_r1_r3 = rational_igual(r1, r3);
printf("%s\n", "r1 igual a r3 (esperado false):");
printf("%d\n", iguais_r1_r3);
struct rational_t soma = rational_soma(r1, r3);
printf("%s\n", "soma r1 + r3, numerador:");
printf("%d\n", soma.numerador);
printf("%s\n", "soma r1 + r3, denominador:");
printf("%d\n", soma.denominador);
struct rational_t neg = rational_negacao(r1);
printf("%s\n", "negacao de r1, numerador:");
printf("%d\n", neg.numerador);
printf("%s\n", "negacao de r1, denominador:");
printf("%d\n", neg.denominador);
struct rational_t sub = rational_subtracao(r1, r3);
printf("%s\n", "subtracao r1 - r3, numerador:");
printf("%d\n", sub.numerador);
printf("%s\n", "subtracao r1 - r3, denominador:");
printf("%d\n", sub.denominador);
struct rational_t mul = rational_multiplicacao(r1, r3);
printf("%s\n", "multiplicacao r1 * r3, numerador:");
printf("%d\n", mul.numerador);
printf("%s\n", "multiplicacao r1 * r3, denominador:");
printf("%d\n", mul.denominador);
struct rational_t inv = rational_inverso(r1);
printf("%s\n", "inverso de r1, numerador:");
printf("%d\n", inv.numerador);
printf("%s\n", "inverso de r1, denominador:");
printf("%d\n", inv.denominador);
struct rational_t div = rational_divisao(r1, r3);
printf("%s\n", "divisao r1 / r3, numerador:");
printf("%d\n", div.numerador);
printf("%s\n", "divisao r1 / r3, denominador:");
printf("%d\n", div.denominador);
return 0;
}

