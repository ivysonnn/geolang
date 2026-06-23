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
int faixa1 = 0;
int faixa2 = 0;
int faixa3 = 0;
int faixa4 = 0;
int continua = 1;
int numero = 0;
L11:
if (continua) goto L12;
goto L13;
L12: {
numero = geolang_read_int("Digite um numero (negativo para parar): ");
if ((numero < 0)) goto L9;
goto L10;
L9: {
continua = 0;
goto L0;
}
L10:
if ((numero <= 25)) goto L1;
goto L2;
L1: {
faixa1 = (faixa1 + 1);
goto L0;
}
L2:
if ((numero <= 50)) goto L3;
goto L4;
L3: {
faixa2 = (faixa2 + 1);
goto L0;
}
L4:
if ((numero <= 75)) goto L5;
goto L6;
L5: {
faixa3 = (faixa3 + 1);
goto L0;
}
L6:
if ((numero <= 100)) goto L7;
goto L8;
L7: {
faixa4 = (faixa4 + 1);
goto L0;
}
L8:
L0: ;
goto L11;
}
L13: ;
printf("%s\n", "Quantidade no intervalo [0, 25]:");
printf("%d\n", faixa1);
printf("%s\n", "Quantidade no intervalo [26, 50]:");
printf("%d\n", faixa2);
printf("%s\n", "Quantidade no intervalo [51, 75]:");
printf("%d\n", faixa3);
printf("%s\n", "Quantidade no intervalo [76, 100]:");
printf("%d\n", faixa4);
return 0;
}

