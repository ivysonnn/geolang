// Problema 6: arvore binaria de busca (chaves inteiras) com as operacoes:
//   A) transformar uma sequencia de valores em uma arvore de busca;
//   B) encontrar a chave minima, indicando seu nivel;
//   C) encontrar a chave maxima, indicando seu nivel;
//   D) imprimir a arvore na saida padrao, nivel a nivel.
//
// Representacao adaptada as caracteristicas da GeoLang. Todos os arranjos
// se traduzem para float* no C reduzido, e um indice de arranjo precisa
// ser uma expressao inteira (usar key[ left[i] ] direto seria um subscrito
// 'float' invalido em C). Por isso a arvore usa um POOL DE NOS em arranjos
// paralelos, e cada ligacao lida de um arranjo e copiada para uma variavel
// int antes de ser usada como indice:
//   key[i]   -> chave do no i                (arranjo de float, impresso com %f)
//   left[i]  -> indice do filho esquerdo     (-1 = vazio)
//   right[i] -> indice do filho direito      (-1 = vazio)
//   count[0] -> quantidade de nos ja criados (proximo indice livre)
// O no raiz e sempre o indice 0. Como cada valor cria exatamente um no,
// o pool tem tamanho = quantidade de valores, sem o crescimento exponencial
// de uma indexacao implicita de heap (suporta arvores degeneradas).
//
// Propriedade da arvore: subarvore esquerda <= chave do no <= direita
// (valores iguais descem para a esquerda).

// A) insere um valor na arvore de busca (pool de nos).
fn inserir(key: mut [float], left: mut [int], right: mut [int], count: mut [int], v: int) {
    var n: int = count[0];

    if n == 0 {
        // primeira insercao: cria a raiz no indice 0
        key[0] = v;
        left[0] = -1;
        right[0] = -1;
        count[0] = 1;
    } else {
        var i: int = 0;
        var colocado: bool = false;

        while colocado == false {
            if v <= key[i] {
                var l: int = left[i];
                if l == -1 {
                    key[n] = v;
                    left[n] = -1;
                    right[n] = -1;
                    left[i] = n;       // liga novo no como filho esquerdo
                    count[0] = n + 1;
                    colocado = true;
                } else {
                    i = l;             // desce para a esquerda
                }
            } else {
                var r: int = right[i];
                if r == -1 {
                    key[n] = v;
                    left[n] = -1;
                    right[n] = -1;
                    right[i] = n;      // liga novo no como filho direito
                    count[0] = n + 1;
                    colocado = true;
                } else {
                    i = r;             // desce para a direita
                }
            }
        }
    }
}

// B) chave minima: desce sempre para a esquerda a partir da raiz.
fn imprimir_min(key: mut [float], left: mut [int]) {
    var i: int = 0;
    var nivel: int = 0;
    var l: int = left[i];

    while l != -1 {
        i = l;
        nivel = nivel + 1;
        l = left[i];
    }

    io.print("Chave minima:");
    io.print(key[i]);
    io.print("Nivel da chave minima:");
    io.print(nivel);
}

// C) chave maxima: desce sempre para a direita a partir da raiz.
fn imprimir_max(key: mut [float], right: mut [int]) {
    var i: int = 0;
    var nivel: int = 0;
    var r: int = right[i];

    while r != -1 {
        i = r;
        nivel = nivel + 1;
        r = right[i];
    }

    io.print("Chave maxima:");
    io.print(key[i]);
    io.print("Nivel da chave maxima:");
    io.print(nivel);
}

// D) impressao nivel a nivel (busca em largura). A fila e um arranjo de
// indices de nos; 'ini' e 'fim' delimitam a janela ativa da fila, e a
// quantidade de nos do nivel atual e (fim - ini) no inicio de cada nivel.
fn imprimir_arvore(key: mut [float], left: mut [int], right: mut [int], count: mut [int]) {
    io.print("Arvore nivel a nivel:");

    var n: int = count[0];

    if n == 0 {
        io.print("(arvore vazia)");
    } else {
        var fila: [int] = allocate(n);
        var ini: int = 0;
        var fim: int = 0;
        var nivel: int = 0;

        fila[fim] = 0;          // enfileira a raiz
        fim = fim + 1;

        while ini < fim {
            var qtd: int = fim - ini;   // nos do nivel atual

            io.print("--- Nivel:");
            io.print(nivel);

            for c in 0..qtd {
                var no: int = fila[ini];
                ini = ini + 1;

                io.print(key[no]);

                var l: int = left[no];
                if l != -1 {
                    fila[fim] = l;
                    fim = fim + 1;
                }

                var r: int = right[no];
                if r != -1 {
                    fila[fim] = r;
                    fim = fim + 1;
                }
            }

            nivel = nivel + 1;
        }
    }
}

fn main() {
    var total: int = io.read_int("Quantos valores deseja inserir? ");

    // Pool de nos: um no por valor lido. count[0] guarda o proximo livre.
    var key: [float] = allocate(total);
    var left: [int] = allocate(total);
    var right: [int] = allocate(total);
    var count: [int] = allocate(1);
    count[0] = 0;

    // A) le a sequencia e monta a arvore de busca
    for k in 0..total {
        var v: int = io.read_int("Digite um valor inteiro: ");
        inserir(key, left, right, count, v);
    }

    if total > 0 {
        imprimir_min(key, left);     // B
        imprimir_max(key, right);    // C
        imprimir_arvore(key, left, right, count);  // D
    } else {
        io.print("Nenhum valor informado.");
    }
}
