CC      = gcc
CFLAGS  = -Wall -Wextra

LEX     = flex
YACC    = bison

SRC_LEXER     = src/lexer/scanner.l
SRC_LEXER_DBG = src/lexer/scanner.debug.l
SRC_PARSER    = src/parser/parser.y
SRC_SEM_C     = src/semantic/symbol_table.c
SRC_SEM_H     = src/semantic/symbol_table.h
SRC_CODEGEN_C = src/codegen/strbuf.c src/codegen/label_gen.c
SRC_CODEGEN_H = src/codegen/strbuf.h src/codegen/label_gen.h

GEN_LEX     = src/lexer/lex.yy.c
GEN_LEX_DBG = src/lexer/lex.debug.yy.c
GEN_PARSER  = src/parser/parser.tab.c
GEN_HDR     = src/parser/parser.tab.h

OUT      = geolang
OUT_DBG  = geolang-debug

# -------------------------------------------------------
# Build completo: parser + lexer + tabela de simbolos + codegen
# -------------------------------------------------------
all: $(OUT)

$(OUT): $(GEN_PARSER) $(GEN_LEX) $(SRC_SEM_C) $(SRC_CODEGEN_C)
	$(CC) $(CFLAGS) -o $(OUT) $(GEN_PARSER) $(GEN_LEX) $(SRC_SEM_C) $(SRC_CODEGEN_C) -lfl

$(GEN_PARSER) $(GEN_HDR): $(SRC_PARSER)
	$(YACC) -d -v -o $(GEN_PARSER) $(SRC_PARSER)

$(GEN_LEX): $(SRC_LEXER) $(GEN_HDR)
	$(LEX) -o $(GEN_LEX) $(SRC_LEXER)

# -------------------------------------------------------
# Build com scanner.debug.l (imprime cada token reconhecido)
# -------------------------------------------------------
debug: $(GEN_PARSER) $(GEN_LEX_DBG) $(SRC_SEM_C) $(SRC_CODEGEN_C)
	$(CC) $(CFLAGS) -o $(OUT_DBG) $(GEN_PARSER) $(GEN_LEX_DBG) $(SRC_SEM_C) $(SRC_CODEGEN_C) -lfl

$(GEN_LEX_DBG): $(SRC_LEXER_DBG) $(GEN_HDR)
	$(LEX) -o $(GEN_LEX_DBG) $(SRC_LEXER_DBG)

# -------------------------------------------------------
# Testes isolados da tabela de simbolos (sem parser)
# -------------------------------------------------------
test-symbols:
	$(CC) $(CFLAGS) -o src/semantic/test_symbol_table \
		src/semantic/symbol_table.c src/semantic/test_symbol_table.c
	./src/semantic/test_symbol_table

# -------------------------------------------------------
# Teste com os exemplos
# -------------------------------------------------------
test:
	./$(OUT) < examples/quicksort.geo

test-minimo:
	./$(OUT) < examples/minimo.geo

test-erro:
	./$(OUT) < examples/erro_sintatico.geo

# -------------------------------------------------------
# Gera o .c reduzido de um exemplo e tenta compila-lo com gcc,
# para validar que o C produzido e sintaticamente valido.
# Uso: make codegen-check FILE=examples/teste_fatorial.geo
# -------------------------------------------------------
codegen-check:
	./$(OUT) < $(FILE) | awk '/=== Codigo C reduzido gerado ===/{flag=1; next} /=== Codigo C salvo em/{flag=0} flag' > /tmp/geolang_codegen_check.c
	$(CC) -Wall -Wextra -c /tmp/geolang_codegen_check.c -o /tmp/geolang_codegen_check.o

# -------------------------------------------------------
# Gera o .c reduzido, compila com gcc e EXECUTA de fato,
# mostrando a saida real do programa traduzido.
# Uso: make run FILE=examples/teste_fatorial.geo
# -------------------------------------------------------
run:
	./$(OUT) < $(FILE) | awk '/=== Codigo C reduzido gerado ===/{flag=1; next} /=== Codigo C salvo em/{flag=0} flag' > /tmp/geolang_run.c
	$(CC) -Wall -Wextra -o /tmp/geolang_run /tmp/geolang_run.c
	@echo "--- saida do programa ---"
	/tmp/geolang_run

clean:
	rm -f $(GEN_LEX) $(GEN_LEX_DBG) $(GEN_PARSER) $(GEN_HDR)
	rm -f src/parser/parser.output
	rm -f $(OUT) $(OUT_DBG)
	rm -f src/semantic/test_symbol_table

# -------------------------------------------------------
# Roda a bateria de testes inteira de uma vez:
#   1. build do projeto
#   2. testes unitarios da tabela de simbolos
#   3. todos os .geo de examples/ e problemas/, com codegen-check
#      (gera o C reduzido e tenta compilar com gcc)
# Ao final mostra um resumo: quantos compilaram (0 erros semanticos
# + C valido) e quantos nao. Cada linha individual mostra o resultado
# real (sucesso/erro semantico/erro sintatico/erro de C)
# -- arquivos de teste de erro proposital DEVEM aparecer como erro
# -------------------------------------------------------
test-all: $(OUT)
	@echo "=================================================="
	@echo " 1. Testes unitarios da tabela de simbolos"
	@echo "=================================================="
	@$(MAKE) --no-print-directory test-symbols || true
	@echo ""
	@echo "=================================================="
	@echo " 2. Todos os programas .geo (examples/ e problemas/)"
	@echo "=================================================="
	@total=0; ok=0; sem_erro=0; sint_erro=0; c_erro=0; \
	for f in examples/*.geo problemas/*.geo; do \
		[ -f "$$f" ] || continue; \
		total=$$((total+1)); \
		out=$$(./$(OUT) "$$f" 2>&1); \
		if echo "$$out" | grep -q "ERRO SINTATICO"; then \
			printf "  [SINTATICO] %-45s\n" "$$f"; \
			sint_erro=$$((sint_erro+1)); \
		elif echo "$$out" | grep -q "erro(s) semantico(s) encontrado"; then \
			printf "  [SEMANTICO] %-45s\n" "$$f"; \
			sem_erro=$$((sem_erro+1)); \
		elif echo "$$out" | grep -q "0 erros semanticos"; then \
			cfile="output/$$(basename $${f%.geo}).c"; \
			if $(CC) -Wall -Wextra -c "$$cfile" -o /tmp/test_all_check.o > /tmp/test_all_check.log 2>&1; then \
				printf "  [OK]        %-45s\n" "$$f"; \
				ok=$$((ok+1)); \
			else \
				printf "  [C INVALIDO]%-45s\n" "$$f"; \
				c_erro=$$((c_erro+1)); \
			fi; \
		else \
			printf "  [INESPERADO]%-45s\n" "$$f"; \
		fi; \
	done; \
	echo ""; \
	echo "=================================================="; \
	echo " Resumo"; \
	echo "=================================================="; \
	echo "  Total de arquivos .geo testados : $$total"; \
	echo "  OK (0 erros + C valido)         : $$ok"; \
	echo "  Erro sintatico                  : $$sint_erro"; \
	echo "  Erro semantico                  : $$sem_erro"; \
	echo "  C gerado invalido (gcc rejeitou): $$c_erro"; \
	echo "=================================================="; \
	echo "Revise as linhas acima: arquivos de teste de erro"; \
	echo "proposital (ex: teste_*_duplicada, teste_*_errado,"; \
	echo "erro_sintatico, teste_semantico) DEVEM aparecer como"; \
	echo "SINTATICO/SEMANTICO -- isso e esperado, nao e falha."; \
	echo "Todos os demais arquivos, incluindo os 6 problemas"; \
	echo "(problema1.geo a problema6.geo) e quicksort.geo,"; \
	echo "DEVEM aparecer como OK."

.PHONY: all debug clean test test-minimo test-erro test-symbols codegen-check run test-all