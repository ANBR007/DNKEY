import AVFAudio
import AppKit
import Combine
import Foundation

/// Estado único do app: descobre packs, liga as peças (tap -> sensor -> engine) e expõe
/// para a UI apenas o que ela precisa desenhar.
final class AppState: ObservableObject {
    enum SensorStatus {
        case active
        case unavailable
    }

    struct PackDescriptor: Identifiable, Hashable {
        let id: String
        let displayName: String
        let url: URL
        let isUser: Bool
    }

    // MARK: - Publicado para a UI

    @Published var enabled: Bool = true {
        didSet {
            guard oldValue != enabled else { return }
            defaults.set(enabled, forKey: Keys.enabled)
        }
    }

    @Published var volume: Double = 0.8 {
        didSet {
            guard oldValue != volume else { return }
            defaults.set(volume, forKey: Keys.volume)
        }
    }

    @Published var useForce: Bool = true {
        didSet {
            guard oldValue != useForce else { return }
            defaults.set(useForce, forKey: Keys.useForce)
            classifier.reset()
            if useForce { startSensor() }
        }
    }

    @Published var currentPackID: String = "mxblue" {
        didSet {
            guard oldValue != currentPackID else { return }
            defaults.set(currentPackID, forKey: Keys.pack)
            loadCurrentPack()
        }
    }

    @Published private(set) var packs: [PackDescriptor] = []
    @Published private(set) var currentPack: SoundPack?
    @Published private(set) var lastIntensity: Double = ForceClassifier.neutral
    @Published private(set) var sensorStatus: SensorStatus = .unavailable
    @Published private(set) var needsAccessibility: Bool = false

    // MARK: - Peças

    private let engine = AudioEngine()
    private let keys = KeyEventSource()
    private let classifier = ForceClassifier()
    private var sensor: ForceSensing = NullForceSensor()
    private let defaults = UserDefaults.standard
    private var permissionTimer: Timer?
    private var variantCounter = 0

    private enum Keys {
        static let enabled = "enabled"
        static let volume = "volume"
        static let useForce = "useForce"
        static let pack = "currentPackID"
    }

    // MARK: - Ciclo de vida

    func boot() {
        restoreSettings()
        reloadPacks()
        _ = engine.start()
        if useForce { startSensor() }
        loadCurrentPack()
        attachKeyTap()
    }

    var userPacksDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("DNKEY/SoundPacks", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func restoreSettings() {
        if defaults.object(forKey: Keys.enabled) != nil { enabled = defaults.bool(forKey: Keys.enabled) }
        if defaults.object(forKey: Keys.volume) != nil { volume = defaults.double(forKey: Keys.volume) }
        if defaults.object(forKey: Keys.useForce) != nil { useForce = defaults.bool(forKey: Keys.useForce) }
        if let saved = defaults.string(forKey: Keys.pack) { currentPackID = saved }
    }

    // MARK: - Acessibilidade

    func requestAccessibility() {
        KeyEventSource.requestAccessibilityPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPermissionPolling()
    }

    private func attachKeyTap() {
        needsAccessibility = !KeyEventSource.hasAccessibilityPermission
        guard !needsAccessibility else {
            startPermissionPolling()
            return
        }
        keys.start { [weak self] event in
            self?.handle(event)
        }
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    /// O sistema não avisa quando a permissão é concedida; sondar é o jeito de o app
    /// voltar a funcionar sem o usuário ter que reabri-lo.
    private func startPermissionPolling() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            if KeyEventSource.hasAccessibilityPermission {
                self.attachKeyTap()
            }
        }
    }

    // MARK: - Sensor

    private func startSensor() {
        if sensor is NullForceSensor {
            let real = ForceSensor()
            real.start()
            sensor = real.isAvailable ? real : NullForceSensor()
        }
        sensorStatus = sensor.isAvailable ? .active : .unavailable
    }

    // MARK: - Packs

    func reloadPacks() {
        var found: [PackDescriptor] = []
        let names = bundledDisplayNames()

        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("SoundPacks", isDirectory: true) {
            found += descriptors(in: bundled, isUser: false, displayNames: names)
        }
        found += descriptors(in: userPacksDirectory, isUser: true, displayNames: [:])

        packs = found.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }

        if !packs.contains(where: { $0.id == currentPackID }), let first = packs.first {
            currentPackID = first.id
        }
    }

    private func descriptors(in directory: URL,
                             isUser: Bool,
                             displayNames: [String: String]) -> [PackDescriptor] {
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(at: directory,
                                                    includingPropertiesForKeys: [.isDirectoryKey],
                                                    options: [.skipsHiddenFiles])) ?? []
        return contents.compactMap { url in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { return nil }
            let id = url.lastPathComponent
            return PackDescriptor(id: isUser ? "user:\(id)" : id,
                                  displayName: displayNames[id] ?? id,
                                  url: url,
                                  isUser: isUser)
        }
    }

    /// desc.json vem do ClickClack no formato {"switches": {"Cherry MX Blue": "mxblue"}}.
    private func bundledDisplayNames() -> [String: String] {
        guard let url = Bundle.main.resourceURL?
                .appendingPathComponent("SoundPacks/desc.json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let switches = root["switches"] as? [String: String]
        else { return [:] }

        var byID: [String: String] = [:]
        for (name, id) in switches { byID[id] = name }
        return byID
    }

    private func loadCurrentPack() {
        guard let descriptor = packs.first(where: { $0.id == currentPackID }) else {
            currentPack = nil
            return
        }
        currentPack = SoundPack.load(id: descriptor.id,
                                     displayName: descriptor.displayName,
                                     directory: descriptor.url,
                                     format: engine.format)
    }

    // MARK: - Importação

    func importPack() {
        let panel = NSOpenPanel()
        panel.title = "Importar meus sons"
        panel.message = "Escolha uma pasta ou arquivos de áudio (mp3, wav, aiff, m4a, caf, flac)"
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true

        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        importPack(from: panel.urls)
    }

    func importPack(from urls: [URL]) {
        let fm = FileManager.default
        let first = urls[0]
        var isDir: ObjCBool = false
        _ = fm.fileExists(atPath: first.path, isDirectory: &isDir)

        let packName = isDir.boolValue ? first.lastPathComponent
                                       : first.deletingPathExtension().lastPathComponent
        let destination = uniqueDestination(named: packName)

        do {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            if isDir.boolValue {
                for item in (try? fm.contentsOfDirectory(at: first, includingPropertiesForKeys: nil)) ?? [] {
                    try? fm.copyItem(at: item, to: destination.appendingPathComponent(item.lastPathComponent))
                }
            } else {
                let audio = urls.filter(AudioFormats.isSupported)
                guard !audio.isEmpty else {
                    try? fm.removeItem(at: destination)
                    alert("Nenhum arquivo de áudio suportado",
                          "Use mp3, wav, aiff, m4a, caf ou flac.")
                    return
                }
                for url in audio {
                    try? fm.copyItem(at: url, to: destination.appendingPathComponent(url.lastPathComponent))
                }
            }
        } catch {
            alert("Não deu para usar esses arquivos", error.localizedDescription)
            return
        }

        // Só aceita o pack se ao menos uma amostra realmente decodificar.
        guard SoundPack.load(id: "probe",
                             displayName: packName,
                             directory: destination,
                             format: engine.format) != nil else {
            try? fm.removeItem(at: destination)
            alert("Não deu para usar esses arquivos",
                  "Os arquivos foram copiados mas nenhum pôde ser decodificado.")
            return
        }

        reloadPacks()
        currentPackID = "user:\(destination.lastPathComponent)"
    }

    private func uniqueDestination(named name: String) -> URL {
        let base = userPacksDirectory
        var candidate = base.appendingPathComponent(name, isDirectory: true)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = base.appendingPathComponent("\(name) \(suffix)", isDirectory: true)
            suffix += 1
        }
        return candidate
    }

    func openUserPacksFolder() {
        NSWorkspace.shared.open(userPacksDirectory)
    }

    private func alert(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Caminho crítico

    private func handle(_ event: KeyEventSource.Event) {
        guard enabled, let pack = currentPack else { return }

        let intensity: Double
        if useForce, let deviation = sensor.peakDeviation(around: event.hostTime) {
            intensity = classifier.classify(deviation)
        } else {
            intensity = ForceClassifier.neutral
        }

        variantCounter &+= 1
        guard let buffer = pack.buffer(for: event.group,
                                       phase: event.phase,
                                       variant: variantCounter) else { return }

        // Batida forte soa mais alta e levemente mais grave; soltar a tecla é sempre mais discreto.
        var gain = Float(volume) * Float(0.70 + 0.55 * intensity)
        if event.phase == .release { gain *= 0.65 }
        let rate = Float(1.05 - 0.10 * intensity)

        engine.play(buffer, volume: min(gain, 1.0), rate: rate)

        if abs(lastIntensity - intensity) > 0.02 {
            lastIntensity = intensity
        }
    }
}
