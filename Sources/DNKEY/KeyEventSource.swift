import AppKit
import CoreGraphics
import Foundation

/// Captura teclas do sistema inteiro via CGEventTap (listen-only: não modifica nem atrasa nada).
final class KeyEventSource {
    struct Event {
        let group: KeyGroup
        let phase: SoundPack.Phase
        let hostTime: UInt64
        let isRepeat: Bool
    }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((Event) -> Void)?
    /// Modificadores só emitem flagsChanged; comparar com o estado anterior diz se foi press ou release.
    private var lastFlags: CGEventFlags = []

    var isRunning: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Abre o diálogo do sistema. Só tem efeito na primeira vez; depois o usuário precisa
    /// liberar manualmente em Ajustes > Privacidade e Segurança > Acessibilidade.
    static func requestAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    @discardableResult
    func start(handler: @escaping (Event) -> Void) -> Bool {
        stop()
        guard Self.hasAccessibilityPermission else { return false }
        self.handler = handler

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let source = Unmanaged<KeyEventSource>.fromOpaque(context).takeUnretainedValue()
                source.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: context
        ) else {
            self.handler = nil
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        handler = nil
        lastFlags = []
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // O sistema desabilita o tap se ele demorar demais; reabilitar é o comportamento correto.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let group = KeyMap.group(for: keyCode)
        let hostTime = UInt64(bitPattern: Int64(event.timestamp))

        switch type {
        case .keyDown:
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            handler?(Event(group: group, phase: .press, hostTime: hostTime, isRepeat: isRepeat))
        case .keyUp:
            handler?(Event(group: group, phase: .release, hostTime: hostTime, isRepeat: false))
        case .flagsChanged:
            let flags = event.flags
            // Ganhou bit = modificador desceu; perdeu bit = subiu.
            let pressed = flags.rawValue > lastFlags.rawValue
            lastFlags = flags
            handler?(Event(group: .generic,
                           phase: pressed ? .press : .release,
                           hostTime: hostTime,
                           isRepeat: false))
        default:
            break
        }
    }
}
