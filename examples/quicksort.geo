// ---------------------------------------------------------
// SUBPROGRAMAS: Implementação do Algoritmo Quicksort
// ---------------------------------------------------------
// Função auxiliar para particionar o arranjo
fn partition(arr: mut [float], low: int, high: int) -> int {
    var pivot: float = arr[high];
    var i: int = low - 1;
    
    // Iterador de intervalo (o transpilador converterá para um for tradicional em C)
    for j in low..high {
        if arr[j] <= pivot {
            i = i + 1;
            
            // Swap (Troca de valores)
            var temp: float = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
        }
    }
    
    // Posiciona o pivô no lugar correto
    var temp_pivot: float = arr[i + 1];
    arr[i + 1] = arr[high];
    arr[high] = temp_pivot;
    
    return i + 1;
}
// Subprograma principal de ordenação (Recursivo)
fn quicksort(arr: mut [float], low: int, high: int) {
    if low < high {
        // Inferência estática de tipo: o compilador sabe que 'partition' retorna 'int'
        var pi = partition(arr, low, high);
        
        quicksort(arr, low, pi - 1);
        quicksort(arr, pi + 1, high);
    }
}
// ---------------------------------------------------------
// PROGRAMA PRINCIPAL: Entrada, Invocação e Saída
// ---------------------------------------------------------
fn main() {
    io.print("SISTEMA GEOLANG - ORDENACAO DE DISTANCIAS");
    
    var n: int = io.read_int("Quantas rotas deseja analisar? ");
    
    // Alocação Dinâmica de Pilha baseada em construtor
    var distancias: [float] = allocate(n); 
    
    // Leitura dos dados
    for i in 0..n {
        io.print("Digite a distancia da rota (em km):");
        io.print(i + 1);
        distancias[i] = io.read_float("Distancia: ");
    }
    
    io.print("Processando ordenacao matricial...");
    
    // Invocação: modificador 'mut' no parâmetro permite alteração in-place
    quicksort(distancias, 0, n - 1);
    
    io.print("--- RESULTADO: DISTANCIAS ORDENADAS (em km) ---");
    for i in 0..n {
        io.print(distancias[i]);
    }
}