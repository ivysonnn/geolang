# Variáveis de Compilação
CC = gcc
FLEX = flex
CFLAGS = -Wall
LIBS = -lfl

# Caminhos
SRC_DIR = src/lexer
BUILD_DIR = build
TARGET = $(BUILD_DIR)/lexer

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

.PHONY: all prepare clean test
