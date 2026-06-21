#include "label_gen.h"
#include <stdio.h>
#include <stdlib.h>

static int g_label_counter = 0;

void label_gen_reset(void) {
    g_label_counter = 0;
}

char *label_gen_new(void) {
    /* "L" + dígitos de um int + terminador. Um int em C tem no       */
    /* máximo 11 caracteres (incluindo sinal), então 16 bytes é        */
    /* espaço de sobra confortável.                                      */
    char *label = (char *)malloc(16);
    snprintf(label, 16, "L%d", g_label_counter);
    g_label_counter++;
    return label;
}