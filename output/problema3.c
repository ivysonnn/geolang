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

float* ler_matriz(int linhas, int colunas) {
int total = (linhas * colunas);
float* m = malloc(total * sizeof(float));
{
int i = 0;
L3:
if (i < linhas) goto L4;
goto L5;
L4: {
{
int j = 0;
L0:
if (j < colunas) goto L1;
goto L2;
L1: {
int indice = ((i * colunas) + j);
m[indice] = geolang_read_float("Valor: ");
j = j + 1;
goto L0;
}
L2: ;
}
i = i + 1;
goto L3;
}
L5: ;
}
return m;
}

void imprimir_matriz(float* m, int linhas, int colunas) {
{
int i = 0;
L9:
if (i < linhas) goto L10;
goto L11;
L10: {
{
int j = 0;
L6:
if (j < colunas) goto L7;
goto L8;
L7: {
int indice = ((i * colunas) + j);
printf("%f\n", m[indice]);
j = j + 1;
goto L6;
}
L8: ;
}
i = i + 1;
goto L9;
}
L11: ;
}
}

float* somar_matrizes(float* a, float* b, int linhas, int colunas) {
int total = (linhas * colunas);
float* resultado = malloc(total * sizeof(float));
{
int i = 0;
L15:
if (i < linhas) goto L16;
goto L17;
L16: {
{
int j = 0;
L12:
if (j < colunas) goto L13;
goto L14;
L13: {
int indice = ((i * colunas) + j);
resultado[indice] = (a[indice] + b[indice]);
j = j + 1;
goto L12;
}
L14: ;
}
i = i + 1;
goto L15;
}
L17: ;
}
return resultado;
}

float* multiplicar_matrizes(float* a, float* b, int la, int ca, int cb) {
int total = (la * cb);
float* resultado = malloc(total * sizeof(float));
{
int i = 0;
L24:
if (i < la) goto L25;
goto L26;
L25: {
{
int j = 0;
L21:
if (j < cb) goto L22;
goto L23;
L22: {
float soma = 0.0;
{
int k = 0;
L18:
if (k < ca) goto L19;
goto L20;
L19: {
int indice_a = ((i * ca) + k);
int indice_b = ((k * cb) + j);
soma = (soma + (a[indice_a] * b[indice_b]));
k = k + 1;
goto L18;
}
L20: ;
}
int indice_resultado = ((i * cb) + j);
resultado[indice_resultado] = soma;
j = j + 1;
goto L21;
}
L23: ;
}
i = i + 1;
goto L24;
}
L26: ;
}
return resultado;
}

int main(void) {
printf("%s\n", "Dimensoes da matriz A:");
int la = geolang_read_int("Linhas de A: ");
int ca = geolang_read_int("Colunas de A: ");
float* a = ler_matriz(la, ca);
printf("%s\n", "Dimensoes da matriz B:");
int lb = geolang_read_int("Linhas de B: ");
int cb = geolang_read_int("Colunas de B: ");
float* b = ler_matriz(lb, cb);
int pode_somar = 0;
if ((la == lb)) goto L31;
goto L32;
L31: {
if ((ca == cb)) goto L29;
goto L30;
L29: {
pode_somar = 1;
goto L28;
}
L30:
L28: ;
goto L27;
}
L32:
L27: ;
if (pode_somar) goto L34;
goto L35;
L34: {
float* soma = somar_matrizes(a, b, la, ca);
printf("%s\n", "Soma de A e B:");
imprimir_matriz(soma, la, ca);
goto L33;
}
L35:
{
printf("%s\n", "Nao e possivel somar: as matrizes tem dimensoes diferentes.");
}
L33: ;
int pode_multiplicar = (ca == lb);
if (pode_multiplicar) goto L37;
goto L38;
L37: {
float* produto = multiplicar_matrizes(a, b, la, ca, cb);
printf("%s\n", "Produto de A por B:");
imprimir_matriz(produto, la, cb);
goto L36;
}
L38:
{
printf("%s\n", "Nao e possivel multiplicar: colunas de A diferem de linhas de B.");
}
L36: ;
return 0;
}

