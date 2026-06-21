#ifndef STRBUF_H
#define STRBUF_H

#include <stddef.h>

typedef struct StrBuf {
    char *data;
    size_t length;
    size_t capacity;
} StrBuf;

StrBuf *strbuf_create(void);
void    strbuf_destroy(StrBuf *sb);

/* Anexa texto literal ao final do buffer. */
void strbuf_append(StrBuf *sb, const char *text);

/* Anexa texto formatado (estilo printf) ao final do buffer. */
void strbuf_appendf(StrBuf *sb, const char *fmt, ...);

/* Anexa o conteúdo de outro StrBuf (não destrói o argumento). */
void strbuf_append_buf(StrBuf *sb, const StrBuf *other);

/* Retorna o conteúdo atual como string C (válido até a próxima    */
/* modificação do buffer ou até strbuf_destroy ser chamado).         */
const char *strbuf_cstr(const StrBuf *sb);

/* Cria uma cópia independente (string alocada com malloc) do        */
/* conteúdo atual. O chamador é responsável por free() na cópia.      */
char *strbuf_dup_cstr(const StrBuf *sb);

#endif /* STRBUF_H */