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

void mdc(int n, int m, float* r) {
int resto_m = (m - (((m / n)) * n));
int resto_n = (n - (((n / m)) * m));
if ((resto_m == 0)) goto L5;
goto L6;
L5: {
r[0] = n;
goto L0;
}
L6:
if ((resto_n == 0)) goto L1;
goto L2;
L1: {
r[0] = m;
goto L0;
}
L2:
if ((m > n)) goto L3;
goto L4;
L3: {
mdc(n, resto_m, r);
goto L0;
}
L4:
{
mdc(m, resto_n, r);
}
L0: ;
}

int main(void) {
int n = geolang_read_int("Digite n (inteiro positivo): ");
int m = geolang_read_int("Digite m (inteiro positivo): ");
float* r = malloc(1 * sizeof(float));
mdc(n, m, r);
printf("%s\n", "Maior divisor comum:");
printf("%f\n", r[0]);
return 0;
}

