// Problema 3: le duas matrizes numericas e, quando possivel, imprime a
// soma e o produto delas. Caso uma operacao nao seja possivel para as
// dimensoes lidas, imprime uma mensagem informando a impossibilidade.
//
// Representacao: como a GeoLang nao possui indexacao multidimensional
// nativa, cada matriz e representada como um arranjo 1D ([float]) de
// tamanho linhas*colunas, com acesso manual via indice = i * colunas + j
// (ordenacao por linhas, "row-major", a mesma convencao usada por C).

fn ler_matriz(linhas: int, colunas: int) -> [float] {
    var total: int = linhas * colunas;
    var m: [float] = allocate(total);

    for i in 0..linhas {
        for j in 0..colunas {
            var indice: int = i * colunas + j;
            m[indice] = io.read_float("Valor: ");
        }
    }

    return m;
}

fn imprimir_matriz(m: mut [float], linhas: int, colunas: int) {
    for i in 0..linhas {
        for j in 0..colunas {
            var indice: int = i * colunas + j;
            io.print(m[indice]);
        }
    }
}

fn somar_matrizes(a: mut [float], b: mut [float], linhas: int, colunas: int) -> [float] {
    var total: int = linhas * colunas;
    var resultado: [float] = allocate(total);

    for i in 0..linhas {
        for j in 0..colunas {
            var indice: int = i * colunas + j;
            resultado[indice] = a[indice] + b[indice];
        }
    }

    return resultado;
}

fn multiplicar_matrizes(a: mut [float], b: mut [float], la: int, ca: int, cb: int) -> [float] {
    var total: int = la * cb;
    var resultado: [float] = allocate(total);

    for i in 0..la {
        for j in 0..cb {
            var soma: float = 0.0;
            for k in 0..ca {
                var indice_a: int = i * ca + k;
                var indice_b: int = k * cb + j;
                soma = soma + a[indice_a] * b[indice_b];
            }
            var indice_resultado: int = i * cb + j;
            resultado[indice_resultado] = soma;
        }
    }

    return resultado;
}

fn main() {
    io.print("Dimensoes da matriz A:");
    var la: int = io.read_int("Linhas de A: ");
    var ca: int = io.read_int("Colunas de A: ");
    var a: [float] = ler_matriz(la, ca);

    io.print("Dimensoes da matriz B:");
    var lb: int = io.read_int("Linhas de B: ");
    var cb: int = io.read_int("Colunas de B: ");
    var b: [float] = ler_matriz(lb, cb);

    // Soma exige que ambas as matrizes tenham as mesmas dimensoes.
    // (a linguagem nao possui operador logico AND; a condicao composta
    // e expressa com ifs aninhados.)
    var pode_somar: bool = false;
    if la == lb {
        if ca == cb {
            pode_somar = true;
        }
    }

    if pode_somar {
        var soma: [float] = somar_matrizes(a, b, la, ca);
        io.print("Soma de A e B:");
        imprimir_matriz(soma, la, ca);
    } else {
        io.print("Nao e possivel somar: as matrizes tem dimensoes diferentes.");
    }

    // Produto exige que o numero de colunas de A seja igual ao numero
    // de linhas de B.
    var pode_multiplicar: bool = ca == lb;

    if pode_multiplicar {
        var produto: [float] = multiplicar_matrizes(a, b, la, ca, cb);
        io.print("Produto de A por B:");
        imprimir_matriz(produto, la, cb);
    } else {
        io.print("Nao e possivel multiplicar: colunas de A diferem de linhas de B.");
    }
}