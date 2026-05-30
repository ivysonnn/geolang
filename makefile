CC      = gcc
CFLAGS  = -Wall -Wextra

LEX     = flex
YACC    = bison

SRC_LEXER  = src/lexer/scanner.l
SRC_PARSER = src/parser/parser.y

GEN_LEX    = src/parser/lex.yy.c
GEN_PARSER = src/parser/parser.tab.c
GEN_HDR    = src/parser/parser.tab.h

OUT = geolang

# -------------------------------------------------------
# Build completo: parser + lexer integrados
# -------------------------------------------------------
all: $(OUT)

$(OUT): $(GEN_PARSER) $(GEN_LEX)
	$(CC) $(CFLAGS) -o $(OUT) $(GEN_PARSER) $(GEN_LEX) -lfl

$(GEN_PARSER) $(GEN_HDR): $(SRC_PARSER)
	$(YACC) -d -v -o $(GEN_PARSER) $(SRC_PARSER)

$(GEN_LEX): $(SRC_LEXER) $(GEN_HDR)
	$(LEX) -o $(GEN_LEX) $(SRC_LEXER)

# -------------------------------------------------------
# Só o lexer (como antes, para testes isolados)
# -------------------------------------------------------
lexer-only:
	$(LEX) -o src/lexer/lex.yy.c $(SRC_LEXER)
	$(CC) $(CFLAGS) -o geolang-lexer src/lexer/lex.yy.c -lfl

# -------------------------------------------------------
# Teste com o exemplo
# -------------------------------------------------------
test:
	./$(OUT) < examples/quicksort.geo

clean:
	rm -f $(GEN_LEX) $(GEN_PARSER) $(GEN_HDR)
	rm -f src/parser/parser.output
	rm -f $(OUT) geolang-lexer