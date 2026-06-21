fn somar_ate(limite: int) -> int {
    var soma: int = 0;
    var i: int = 1;
    while i <= limite {
        soma = soma + i;
        i = i + 1;
    }
    return soma;
}

fn contar_do_while(n: int) -> int {
    var contador: int = 0;
    do {
        contador = contador + 1;
    } while contador < n;
    return contador;
}

fn main() {
    var s: int = somar_ate(10);
    var c: int = contar_do_while(5);
}