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

void inserir(float* key, float* left, float* right, float* count, int v) {
int n = count[0];
if ((n == 0)) goto L13;
goto L14;
L13: {
key[0] = v;
left[0] = (-1);
right[0] = (-1);
count[0] = 1;
goto L0;
}
L14:
{
int i = 0;
int colocado = 0;
L10:
if ((colocado == 0)) goto L11;
goto L12;
L11: {
if ((v <= key[i])) goto L8;
goto L9;
L8: {
int l = left[i];
if ((l == (-1))) goto L3;
goto L4;
L3: {
key[n] = v;
left[n] = (-1);
right[n] = (-1);
left[i] = n;
count[0] = (n + 1);
colocado = 1;
goto L2;
}
L4:
{
i = l;
}
L2: ;
goto L1;
}
L9:
{
int r = right[i];
if ((r == (-1))) goto L6;
goto L7;
L6: {
key[n] = v;
left[n] = (-1);
right[n] = (-1);
right[i] = n;
count[0] = (n + 1);
colocado = 1;
goto L5;
}
L7:
{
i = r;
}
L5: ;
}
L1: ;
goto L10;
}
L12: ;
}
L0: ;
}

void imprimir_min(float* key, float* left) {
int i = 0;
int nivel = 0;
int l = left[i];
L15:
if ((l != (-1))) goto L16;
goto L17;
L16: {
i = l;
nivel = (nivel + 1);
l = left[i];
goto L15;
}
L17: ;
printf("%s\n", "Chave minima:");
printf("%f\n", key[i]);
printf("%s\n", "Nivel da chave minima:");
printf("%d\n", nivel);
}

void imprimir_max(float* key, float* right) {
int i = 0;
int nivel = 0;
int r = right[i];
L18:
if ((r != (-1))) goto L19;
goto L20;
L19: {
i = r;
nivel = (nivel + 1);
r = right[i];
goto L18;
}
L20: ;
printf("%s\n", "Chave maxima:");
printf("%f\n", key[i]);
printf("%s\n", "Nivel da chave maxima:");
printf("%d\n", nivel);
}

void imprimir_arvore(float* key, float* left, float* right, float* count) {
printf("%s\n", "Arvore nivel a nivel:");
int n = count[0];
if ((n == 0)) goto L34;
goto L35;
L34: {
printf("%s\n", "(arvore vazia)");
goto L21;
}
L35:
{
float* fila = malloc(n * sizeof(float));
int ini = 0;
int fim = 0;
int nivel = 0;
fila[fim] = 0;
fim = (fim + 1);
L31:
if ((ini < fim)) goto L32;
goto L33;
L32: {
int qtd = (fim - ini);
printf("%s\n", "--- Nivel:");
printf("%d\n", nivel);
{
int c = 0;
L28:
if (c < qtd) goto L29;
goto L30;
L29: {
int no = fila[ini];
ini = (ini + 1);
printf("%f\n", key[no]);
int l = left[no];
if ((l != (-1))) goto L23;
goto L24;
L23: {
fila[fim] = l;
fim = (fim + 1);
goto L22;
}
L24:
L22: ;
int r = right[no];
if ((r != (-1))) goto L26;
goto L27;
L26: {
fila[fim] = r;
fim = (fim + 1);
goto L25;
}
L27:
L25: ;
c = c + 1;
goto L28;
}
L30: ;
}
nivel = (nivel + 1);
goto L31;
}
L33: ;
}
L21: ;
}

int main(void) {
int total = geolang_read_int("Quantos valores deseja inserir? ");
float* key = malloc(total * sizeof(float));
float* left = malloc(total * sizeof(float));
float* right = malloc(total * sizeof(float));
float* count = malloc(1 * sizeof(float));
count[0] = 0;
{
int k = 0;
L36:
if (k < total) goto L37;
goto L38;
L37: {
int v = geolang_read_int("Digite um valor inteiro: ");
inserir(key, left, right, count, v);
k = k + 1;
goto L36;
}
L38: ;
}
if ((total > 0)) goto L40;
goto L41;
L40: {
imprimir_min(key, left);
imprimir_max(key, right);
imprimir_arvore(key, left, right, count);
goto L39;
}
L41:
{
printf("%s\n", "Nenhum valor informado.");
}
L39: ;
return 0;
}

