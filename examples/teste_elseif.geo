fn classificar(nota: int) -> int {
    if nota >= 90 {
        return 1;
    } elseif nota >= 70 {
        return 2;
    } elseif nota >= 50 {
        return 3;
    } else {
        return 4;
    }
}

fn main() {
    var a: int = classificar(95);
    var b: int = classificar(75);
    var c: int = classificar(55);
    var d: int = classificar(20);
}