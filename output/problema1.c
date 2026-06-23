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

int main(void) {
float x = 3.5;
float y = 2.0;
int c = 4;
float resultado = (((x * x) - y) + c);
printf("%f\n", resultado);
return 0;
}

