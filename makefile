# Variáveis de Compilação
CC = gcc
FLEX = flex
CFLAGS = -Wall
LIBS = -lfl

# Caminhos
SRC_DIR = src/lexer
BUILD_DIR = build
TARGET = $(BUILD_DIR)/lexer
DEBUG_TARGET = $(BUILD_DIR)/lexer_debug

# Arquivos
LEX_SRC = $(SRC_DIR)/scanner.l
LEX_OUT = $(BUILD_DIR)/lex.yy.c

# Comando padrão: compila tudo
all: prepare $(TARGET)

# Cria a pasta build se não existir
prepare:
	mkdir -p $(BUILD_DIR)

# Gera o código C a partir do Flex
$(LEX_OUT): $(LEX_SRC)
	$(FLEX) -o $(LEX_OUT) $(LEX_SRC)

# Compila o executável final
$(TARGET): $(LEX_OUT)
	$(CC) $(CFLAGS) $(LEX_OUT) -I$(SRC_DIR) -o $(TARGET) $(LIBS)

clean:
	rm -rf $(BUILD_DIR)

# Executa o lexer com o exemplo de teste automaticamente
test: all
	./$(TARGET) < examples/quicksort.geo
debug: prepare
	$(FLEX) -o $(BUILD_DIR)/scanner.debug.c $(SRC_DIR)/scanner.debug.l
	$(CC) $(CFLAGS) $(BUILD_DIR)/scanner.debug.c -I$(SRC_DIR) -o $(DEBUG_TARGET) $(LIBS)
	./$(DEBUG_TARGET) < examples/quicksort.geo

.PHONY: all prepare clean test
