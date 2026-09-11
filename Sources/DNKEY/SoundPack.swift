import AVFAudio
import Foundation

/// Um conjunto de amostras já decodificadas em memória, pronto para tocar sem I/O no caminho crítico.
final class SoundPack {
    enum Phase {
        case press
        case release
    }

    let id: String
    let displayName: String

    private let press: [KeyGroup: [AVAudioPCMBuffer]]
    private let release: [KeyGroup: [AVAudioPCMBuffer]]

    init(id: String,
         displayName: String,
         press: [KeyGroup: [AVAudioPCMBuffer]],
         release: [KeyGroup: [AVAudioPCMBuffer]]) {
        self.id = id
        self.displayName = displayName
        self.press = press
        self.release = release
    }

    var isEmpty: Bool { press.isEmpty && release.isEmpty }

    /// Busca a amostra do grupo pedido, caindo para GENERIC quando o pack não tem tecla dedicada.
    /// `variant` roda em round-robin sobre as variações (_R0.._R4) para o som não ficar mecânico.
    func buffer(for group: KeyGroup, phase: Phase, variant: Int) -> AVAudioPCMBuffer? {
        let table = (phase == .press) ? press : release
        guard let list = table[group] ?? table[.generic], !list.isEmpty else { return nil }
        return list[abs(variant) % list.count]
    }

    // MARK: - Carregamento

    static func load(id: String,
                     displayName: String,
                     directory: URL,
                     format: AVAudioFormat) -> SoundPack? {
        let fm = FileManager.default
        let pressDir = directory.appendingPathComponent("press")
        let releaseDir = directory.appendingPathComponent("release")

        var pressTable = samples(in: pressDir, format: format)
        let releaseTable = samples(in: releaseDir, format: format)

        // Pack "plano": pasta com áudios soltos (caso comum em importações do usuário).
        if pressTable.isEmpty && releaseTable.isEmpty {
            let flat = audioFiles(in: directory, fm: fm)
                .compactMap { AudioFormats.decode($0, to: format) }
            guard !flat.isEmpty else { return nil }
            pressTable = [.generic: flat]
            return SoundPack(id: id, displayName: displayName, press: pressTable, release: [:])
        }

        guard !pressTable.isEmpty || !releaseTable.isEmpty else { return nil }
        return SoundPack(id: id, displayName: displayName, press: pressTable, release: releaseTable)
    }

    private static func samples(in directory: URL,
                                format: AVAudioFormat) -> [KeyGroup: [AVAudioPCMBuffer]] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDir), isDir.boolValue else {
            return [:]
        }

        var table: [KeyGroup: [AVAudioPCMBuffer]] = [:]
        // Ordena por nome para que _R0.._R4 entrem sempre na mesma ordem entre execuções.
        for url in audioFiles(in: directory, fm: fm).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let buffer = AudioFormats.decode(url, to: format) else { continue }
            table[group(fromFileName: url), default: []].append(buffer)
        }
        return table
    }

    private static func audioFiles(in directory: URL, fm: FileManager) -> [URL] {
        let contents = (try? fm.contentsOfDirectory(at: directory,
                                                    includingPropertiesForKeys: [.isRegularFileKey],
                                                    options: [.skipsHiddenFiles])) ?? []
        return contents.filter(AudioFormats.isSupported)
    }

    /// "GENERIC_R3.mp3" -> .generic ; "SPACE.mp3" -> .space ; desconhecido -> .generic
    private static func group(fromFileName url: URL) -> KeyGroup {
        var name = url.deletingPathExtension().lastPathComponent.uppercased()
        if let range = name.range(of: "_R", options: .backwards),
           name[range.upperBound...].allSatisfy(\.isNumber),
           !name[range.upperBound...].isEmpty {
            name = String(name[name.startIndex..<range.lowerBound])
        }
        return KeyGroup(rawValue: name) ?? .generic
    }
}
