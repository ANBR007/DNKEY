import Foundation

/// Uma amostra do acelerômetro: quando chegou (mach absolute time) e o quanto desviou.
struct AccelSample {
    let hostTime: UInt64
    let magnitude: Double
}

/// Fonte de intensidade de batida. O app funciona inteiro sem ela — por isso é protocolo.
protocol ForceSensing: AnyObject {
    var isAvailable: Bool { get }
    func start()
    /// Maior desvio observado numa janela em torno do instante da tecla, ou nil se não houver dado.
    func peakDeviation(around hostTime: UInt64) -> Double?
}

/// Usado quando não há acelerômetro (Mac Intel, permissão negada, hardware sem sensor).
final class NullForceSensor: ForceSensing {
    var isAvailable: Bool { false }
    func start() {}
    func peakDeviation(around hostTime: UInt64) -> Double? { nil }
}
