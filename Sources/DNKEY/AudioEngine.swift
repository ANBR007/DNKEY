import AVFAudio
import Foundation

/// Pool de vozes pré-conectadas. Tocar uma tecla nunca aloca nem reconecta nada —
/// só escolhe a próxima voz livre, ajusta rate/volume e agenda o buffer.
final class AudioEngine {
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var varispeeds: [AVAudioUnitVarispeed] = []
    private let voiceCount: Int
    private var cursor = 0
    private let lock = NSLock()

    /// Formato comum a todas as amostras: converter na importação evita conversão no play.
    let format: AVAudioFormat

    init(voiceCount: Int = 24) {
        self.voiceCount = voiceCount
        self.format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

        for _ in 0..<voiceCount {
            let player = AVAudioPlayerNode()
            let varispeed = AVAudioUnitVarispeed()
            engine.attach(player)
            engine.attach(varispeed)
            engine.connect(player, to: varispeed, format: format)
            engine.connect(varispeed, to: engine.mainMixerNode, format: format)
            players.append(player)
            varispeeds.append(varispeed)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    var isRunning: Bool { engine.isRunning }

    @discardableResult
    func start() -> Bool {
        guard !engine.isRunning else { return true }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            return false
        }
        for player in players where !player.isPlaying {
            player.play()
        }
        return true
    }

    /// `rate` desloca levemente o pitch conforme a intensidade da batida (DSP em cima de uma
    /// única amostra, em vez de exigir 4 gravações por tecla).
    func play(_ buffer: AVAudioPCMBuffer, volume: Float, rate: Float) {
        guard engine.isRunning else { return }

        lock.lock()
        let index = cursor % voiceCount
        cursor &+= 1
        lock.unlock()

        let player = players[index]
        let varispeed = varispeeds[index]

        varispeed.rate = max(0.5, min(2.0, rate))
        player.volume = max(0.0, min(1.0, volume))
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    /// Troca de saída de áudio (fone conectado, dock, etc.) derruba o engine: reergue.
    @objc private func handleConfigurationChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.engine.isRunning else { return }
            _ = self.start()
        }
    }
}
