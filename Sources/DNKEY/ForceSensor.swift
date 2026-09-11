import Foundation
import IOKit
import IOKit.hid

/// Lê o acelerômetro embutido (AppleSPUHIDDevice, presente nos Macs Apple Silicon) e guarda
/// um anel de amostras. Cada tecla depois pergunta "quanto o chassi vibrou por volta deste
/// instante?" — é isso que vira a intensidade da batida.
final class ForceSensor: ForceSensing {
    /// Janela em torno do timestamp da tecla. O impacto chega ao sensor alguns ms depois do evento.
    private static let correlationWindowNs: UInt64 = 45_000_000  // 45 ms

    private let historySize = 512
    private var history: [AccelSample]
    private var writeIndex = 0
    private var baseline: Double = 0
    private var manager: IOHIDManager?
    private var available = false
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.anbr007.dnkey.force", qos: .userInitiated)
    private var timebase = mach_timebase_info_data_t()

    init() {
        history = Array(repeating: AccelSample(hostTime: 0, magnitude: 0), count: historySize)
        mach_timebase_info(&timebase)
    }

    var isAvailable: Bool {
        lock.lock(); defer { lock.unlock() }
        return available
    }

    func start() {
        guard manager == nil else { return }

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        // Página de uso "Sensor" (0x20) — é onde o acelerômetro do chassi se anuncia.
        let matching: [String: Any] = [kIOHIDPrimaryUsagePageKey: 0x20]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            let sensor = Unmanaged<ForceSensor>.fromOpaque(context).takeUnretainedValue()
            sensor.record(value)
        }, context)

        // A ordem importa: abrir antes de ativar. Ativar primeiro faz o IOKit abortar o processo
        // ("Device has already been activated/cancelled") quando o Open enumera os dispositivos.
        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else {
            self.manager = nil
            return
        }

        IOHIDManagerSetDispatchQueue(manager, queue)
        IOHIDManagerActivate(manager)

        lock.lock()
        available = true
        lock.unlock()
    }

    func peakDeviation(around hostTime: UInt64) -> Double? {
        lock.lock(); defer { lock.unlock() }
        guard available else { return nil }

        let window = Self.correlationWindowNs
        var peak: Double = 0
        var found = false

        for sample in history where sample.hostTime != 0 {
            let elapsed = nanoseconds(from: sample.hostTime, to: hostTime)
            guard abs(elapsed) <= Int64(window) else { continue }
            peak = max(peak, abs(sample.magnitude - baseline))
            found = true
        }
        return found ? peak : nil
    }

    // MARK: - Interno

    private func record(_ value: IOHIDValue) {
        let magnitude = abs(Double(IOHIDValueGetIntegerValue(value)))
        guard magnitude.isFinite else { return }
        let hostTime = IOHIDValueGetTimeStamp(value)

        lock.lock()
        history[writeIndex] = AccelSample(hostTime: hostTime, magnitude: magnitude)
        writeIndex = (writeIndex + 1) % historySize
        // Média móvel lenta: o repouso do sensor varia com posição e temperatura do Mac.
        baseline += (magnitude - baseline) * 0.01
        lock.unlock()
    }

    private func nanoseconds(from a: UInt64, to b: UInt64) -> Int64 {
        let delta = Int64(bitPattern: b &- a)
        guard timebase.denom != 0 else { return delta }
        return delta * Int64(timebase.numer) / Int64(timebase.denom)
    }
}
