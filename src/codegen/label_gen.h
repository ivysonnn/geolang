#ifndef LABEL_GEN_H
#define LABEL_GEN_H


/* Reinicia o contador de labels (chamar no início da compilação    */
/* de cada programa, antes do primeiro uso).                          */
void label_gen_reset(void);

/* Gera e retorna um novo nome de rótulo único, no formato "L<n>".   */
/* A string retornada é alocada com malloc; o chamador é               */
/* responsável por liberar com free() quando não precisar mais.        */
char *label_gen_new(void);

#endif /* LABEL_GEN_H */