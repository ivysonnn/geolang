struct Ponto {
    x: float;
    y: float;
}

fn distancia(a: Ponto, b: Ponto) -> float {
    var dx: float = a.x - b.x;
    var dy: float = a.y - b.y;
    return dx * dx + dy * dy;
}

fn main() {
    var p1: Ponto;
    var p2: Ponto;
    var d: float = distancia(p1, p2);

    var contador: int = 0;
    for i in 0..10 {
        contador = contador + 1;
    }

    var ativo: bool = true;
    while ativo {
        ativo = false;
    }

    var k: int = 0;
    do {
        k = k + 1;
    } while k < 5;

    if contador > 5 {
        var msg: string = "maior";
    } elseif contador == 5 {
        var msg: string = "igual";
    } else {
        var msg: string = "menor";
    }
}