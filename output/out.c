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

int partition(float* arr, int low, int high) {
float pivot = arr[high];
int i = (low - 1);
{
int j = low;
L3:
if (j < high) goto L4;
goto L5;
L4: {
if ((arr[j] <= pivot)) goto L1;
goto L2;
L1: {
i = (i + 1);
float temp = arr[i];
arr[i] = arr[j];
arr[j] = temp;
goto L0;
}
L2:
L0: ;
j = j + 1;
goto L3;
}
L5: ;
}
float temp_pivot = arr[(i + 1)];
arr[(i + 1)] = arr[high];
arr[high] = temp_pivot;
return (i + 1);
}

void quicksort(float* arr, int low, int high) {
if ((low < high)) goto L7;
goto L8;
L7: {
int pi = partition(arr, low, high);
quicksort(arr, low, (pi - 1));
quicksort(arr, (pi + 1), high);
goto L6;
}
L8:
L6: ;
}

int main(void) {
printf("%s\n", "SISTEMA GEOLANG - ORDENACAO DE DISTANCIAS");
int n = geolang_read_int("Quantas rotas deseja analisar? ");
float* distancias = malloc(n * sizeof(float));
{
int i = 0;
L9:
if (i < n) goto L10;
goto L11;
L10: {
distancias[i] = geolang_read_float((("Digite a distancia da rota " + ((i + 1))) + " (em km):"));
i = i + 1;
goto L9;
}
L11: ;
}
printf("%s\n", "Processando ordenacao matricial...");
quicksort(distancias, 0, (n - 1));
printf("%s\n", "--- RESULTADO: DISTANCIAS ORDENADAS ---");
{
int i = 0;
L12:
if (i < n) goto L13;
goto L14;
L13: {
printf("%s\n", (distancias[i] + " km"));
i = i + 1;
goto L12;
}
L14: ;
}
return 0;
}

