#include "strbuf.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#define STRBUF_INITIAL_CAPACITY 256

StrBuf *strbuf_create(void) {
    StrBuf *sb = (StrBuf *)malloc(sizeof(StrBuf));
    sb->data = (char *)malloc(STRBUF_INITIAL_CAPACITY);
    sb->data[0] = '\0';
    sb->length = 0;
    sb->capacity = STRBUF_INITIAL_CAPACITY;
    return sb;
}

void strbuf_destroy(StrBuf *sb) {
    if (sb == NULL) return;
    free(sb->data);
    free(sb);
}

/* Garante espaço para 'extra' bytes adicionais (+1 para o '\0'),   */
/* dobrando a capacidade quantas vezes forem necessárias.            */
static void strbuf_ensure_capacity(StrBuf *sb, size_t extra) {
    size_t needed = sb->length + extra + 1;
    if (needed <= sb->capacity) return;

    size_t new_capacity = sb->capacity;
    while (new_capacity < needed) {
        new_capacity *= 2;
    }

    sb->data = (char *)realloc(sb->data, new_capacity);
    sb->capacity = new_capacity;
}

void strbuf_append(StrBuf *sb, const char *text) {
    size_t text_len = strlen(text);
    strbuf_ensure_capacity(sb, text_len);
    memcpy(sb->data + sb->length, text, text_len + 1);
    sb->length += text_len;
}

void strbuf_appendf(StrBuf *sb, const char *fmt, ...) {
    va_list args;

    /* Primeira passada: descobre o tamanho necessário. */
    va_start(args, fmt);
    int needed = vsnprintf(NULL, 0, fmt, args);
    va_end(args);

    if (needed < 0) return;

    strbuf_ensure_capacity(sb, (size_t)needed);

    /* Segunda passada: escreve de fato no espaço já garantido. */
    va_start(args, fmt);
    vsnprintf(sb->data + sb->length, (size_t)needed + 1, fmt, args);
    va_end(args);

    sb->length += (size_t)needed;
}

void strbuf_append_buf(StrBuf *sb, const StrBuf *other) {
    strbuf_append(sb, other->data);
}

const char *strbuf_cstr(const StrBuf *sb) {
    return sb->data;
}

char *strbuf_dup_cstr(const StrBuf *sb) {
    char *copy = (char *)malloc(sb->length + 1);
    memcpy(copy, sb->data, sb->length + 1);
    return copy;
}