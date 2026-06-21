fn fatorial(n: int) -> int {
    if n <= 1 {
        return 1;
    } else {
        var resto: int = fatorial(n - 1);
        return n * resto;
    }
}

fn main() {
    var resultado: int = fatorial(5);
}