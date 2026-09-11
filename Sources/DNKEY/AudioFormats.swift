import AVFAudio
import Foundation

/// Decodificação de qualquer formato que o CoreAudio abra para o formato do engine.
enum AudioFormats {
    static let supportedExtensions: Set<String> = [
        "mp3", "wav", "aiff", "aif", "aifc", "m4a", "caf", "flac"
    ]

    static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }

    /// Lê o arquivo inteiro para memória e converte para `format`.
    /// Retorna nil em vez de lançar: um arquivo ruim não pode derrubar a importação inteira.
    static func decode(_ url: URL, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }

        let sourceFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let source = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount)
        else { return nil }

        do { try file.read(into: source) } catch { return nil }
        guard source.frameLength > 0 else { return nil }
        if sourceFormat == format { return source }

        guard let converter = AVAudioConverter(from: sourceFormat, to: format) else { return nil }
        let ratio = format.sampleRate / sourceFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(source.frameLength) * ratio) + 4096
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        var delivered = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if delivered {
                outStatus.pointee = .endOfStream
                return nil
            }
            delivered = true
            outStatus.pointee = .haveData
            return source
        }

        guard status != .error, conversionError == nil, output.frameLength > 0 else { return nil }
        return output
    }
}
