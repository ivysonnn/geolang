// Problema 2: le uma quantidade desconhecida de numeros e conta quantos
// caem em cada uma das faixas [0,25], [26,50], [51,75], [76,100].
// A leitura termina quando um numero negativo e informado.
fn main() {
    var faixa1: int = 0;
    var faixa2: int = 0;
    var faixa3: int = 0;
    var faixa4: int = 0;

    var continua: bool = true;
    var numero: int = 0;

    while continua {
        numero = io.read_int("Digite um numero (negativo para parar): ");

        if numero < 0 {
            continua = false;
        } elseif numero <= 25 {
            faixa1 = faixa1 + 1;
        } elseif numero <= 50 {
            faixa2 = faixa2 + 1;
        } elseif numero <= 75 {
            faixa3 = faixa3 + 1;
        } elseif numero <= 100 {
            faixa4 = faixa4 + 1;
        }
    }

    io.print("Quantidade no intervalo [0, 25]:");
    io.print(faixa1);
    io.print("Quantidade no intervalo [26, 50]:");
    io.print(faixa2);
    io.print("Quantidade no intervalo [51, 75]:");
    io.print(faixa3);
    io.print("Quantidade no intervalo [76, 100]:");
    io.print(faixa4);
}