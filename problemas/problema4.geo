// Problema 4: define o tipo rational_t (numerador/denominador) e
// subprogramas para criar, comparar e operar sobre numeros racionais.

struct rational_t {
    numerador: int;
    denominador: int;
}

// A) Cria um rational_t representando a fracao a/b (b != 0).
fn rational_criar(a: int, b: int) -> rational_t {
    var r: rational_t;
    r.numerador = a;
    r.denominador = b;
    return r;
}

// B) Compara se dois racionais representam o mesmo numero, mesmo que
// estejam em formas diferentes (ex: 1/2 e 2/4). A comparacao e feita
// por multiplicacao cruzada (a/b == c/d  <=>  a*d == c*b), evitando
// comparar os structs diretamente (igualdade de struct nao e
// suportada pelo C reduzido gerado).
fn rational_igual(r1: rational_t, r2: rational_t) -> bool {
    var igual: bool = r1.numerador * r2.denominador == r2.numerador * r1.denominador;
    return igual;
}

// C) Operacoes aritmeticas entre racionais.

fn rational_soma(r1: rational_t, r2: rational_t) -> rational_t {
    var num: int = r1.numerador * r2.denominador + r2.numerador * r1.denominador;
    var den: int = r1.denominador * r2.denominador;
    return rational_criar(num, den);
}

fn rational_negacao(r: rational_t) -> rational_t {
    var num: int = 0 - r.numerador;
    return rational_criar(num, r.denominador);
}

fn rational_subtracao(r1: rational_t, r2: rational_t) -> rational_t {
    var r2_neg: rational_t = rational_negacao(r2);
    return rational_soma(r1, r2_neg);
}

fn rational_multiplicacao(r1: rational_t, r2: rational_t) -> rational_t {
    var num: int = r1.numerador * r2.numerador;
    var den: int = r1.denominador * r2.denominador;
    return rational_criar(num, den);
}

fn rational_inverso(r: rational_t) -> rational_t {
    return rational_criar(r.denominador, r.numerador);
}

fn rational_divisao(r1: rational_t, r2: rational_t) -> rational_t {
    var r2_inv: rational_t = rational_inverso(r2);
    return rational_multiplicacao(r1, r2_inv);
}

fn main() {
    var r1: rational_t = rational_criar(1, 2);
    var r2: rational_t = rational_criar(2, 4);
    var r3: rational_t = rational_criar(1, 3);

    io.print("r1 = 1/2, r2 = 2/4, r3 = 1/3");

    var iguais_r1_r2: bool = rational_igual(r1, r2);
    io.print("r1 igual a r2 (esperado true):");
    io.print(iguais_r1_r2);

    var iguais_r1_r3: bool = rational_igual(r1, r3);
    io.print("r1 igual a r3 (esperado false):");
    io.print(iguais_r1_r3);

    var soma: rational_t = rational_soma(r1, r3);
    io.print("soma r1 + r3, numerador:");
    io.print(soma.numerador);
    io.print("soma r1 + r3, denominador:");
    io.print(soma.denominador);

    var neg: rational_t = rational_negacao(r1);
    io.print("negacao de r1, numerador:");
    io.print(neg.numerador);
    io.print("negacao de r1, denominador:");
    io.print(neg.denominador);

    var sub: rational_t = rational_subtracao(r1, r3);
    io.print("subtracao r1 - r3, numerador:");
    io.print(sub.numerador);
    io.print("subtracao r1 - r3, denominador:");
    io.print(sub.denominador);

    var mul: rational_t = rational_multiplicacao(r1, r3);
    io.print("multiplicacao r1 * r3, numerador:");
    io.print(mul.numerador);
    io.print("multiplicacao r1 * r3, denominador:");
    io.print(mul.denominador);

    var inv: rational_t = rational_inverso(r1);
    io.print("inverso de r1, numerador:");
    io.print(inv.numerador);
    io.print("inverso de r1, denominador:");
    io.print(inv.denominador);

    var div: rational_t = rational_divisao(r1, r3);
    io.print("divisao r1 / r3, numerador:");
    io.print(div.numerador);
    io.print("divisao r1 / r3, denominador:");
    io.print(div.denominador);
}