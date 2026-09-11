import CoreGraphics

/// Grupos de tecla que possuem amostra própria nos sound packs.
/// Os nomes crus correspondem aos arquivos do pack (GENERIC_R0.mp3, SPACE.mp3, ...).
enum KeyGroup: String, CaseIterable {
    case generic = "GENERIC"
    case space = "SPACE"
    case enter = "ENTER"
    case backspace = "BACKSPACE"
}

enum KeyMap {
    /// Códigos virtuais do Carbon (kVK_*) que ganham som dedicado.
    private static let space: CGKeyCode = 49
    private static let returnKey: CGKeyCode = 36
    private static let keypadEnter: CGKeyCode = 76
    private static let delete: CGKeyCode = 51
    private static let forwardDelete: CGKeyCode = 117

    static func group(for keyCode: CGKeyCode) -> KeyGroup {
        switch keyCode {
        case space: return .space
        case returnKey, keypadEnter: return .enter
        case delete, forwardDelete: return .backspace
        default: return .generic
        }
    }
}
