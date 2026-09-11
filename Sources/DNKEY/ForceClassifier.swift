import Foundation

/// Converte o desvio cru do acelerômetro numa intensidade 0...1.
/// A normalização é adaptativa: cada pessoa (e cada mesa) tem uma faixa de força diferente,
/// então calibrar por percentis do histórico recente funciona melhor que limiar fixo.
final class ForceClassifier {
    private let historySize = 80
    private var history: [Double] = []
    private let lock = NSLock()

    /// Intensidade neutra usada quando não há sensor ou ainda não há dado suficiente.
    static let neutral: Double = 0.5

    func classify(_ deviation: Double?) -> Double {
        guard let deviation, deviation.isFinite, deviation > 0 else { return Self.neutral }

        lock.lock()
        history.append(deviation)
        if history.count > historySize {
            history.removeFirst(history.count - historySize)
        }
        let samples = history
        lock.unlock()

        guard samples.count >= 8 else { return Self.neutral }

        let sorted = samples.sorted()
        let last = Double(sorted.count - 1)
        let low = sorted[Int(last * 0.10)]
        let high = sorted[Int(last * 0.90)]
        guard high > low else { return Self.neutral }

        return min(1.0, max(0.0, (deviation - low) / (high - low)))
    }

    func reset() {
        lock.lock()
        history.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}
