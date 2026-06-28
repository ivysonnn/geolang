// Problema 5: subprograma 'mdc' com argumentos n, m (por valor) e
// r (por referencia), nesta ordem. Calcula o maior divisor comum entre
// dois naturais estritamente positivos n e m de forma recursiva e
// devolve o resultado pelo parametro r, impresso pelo programa principal.
//
// GeoLang nao possui operador de modulo (%); o resto de m por n e
// obtido com divisao inteira: m - (m / n) * n.
fn mdc(n: int, m: int, r: mut [float]) {
    var resto_m: int = m - (m / n) * n;   // m mod n
    var resto_n: int = n - (n / m) * m;   // n mod m

    if resto_m == 0 {
        // n e divisor de m -> n e o mdc
        r[0] = n;
    } elseif resto_n == 0 {
        // m e divisor de n -> m e o mdc
        r[0] = m;
    } elseif m > n {
        // mdc(m, n) = mdc(n, m mod n)
        mdc(n, resto_m, r);
    } else {
        // adaptacao simetrica para garantir o caso n > m
        mdc(m, resto_n, r);
    }
}

fn main() {
    var n: int = io.read_int("Digite n (inteiro positivo): ");
    var m: int = io.read_int("Digite m (inteiro positivo): ");

    var r: [float] = allocate(1);

    mdc(n, m, r);

    io.print("Maior divisor comum:");
    io.print(r[0]);
}
