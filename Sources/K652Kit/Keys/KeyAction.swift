import Foundation

/// Modificadores no formato do relatório de teclado HID (o mesmo byte que o driver grava na matriz).
public struct KeyModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let leftControl = KeyModifiers(rawValue: 0x01)
    public static let leftShift = KeyModifiers(rawValue: 0x02)
    public static let leftAlt = KeyModifiers(rawValue: 0x04)
    public static let leftGUI = KeyModifiers(rawValue: 0x08)
    public static let rightControl = KeyModifiers(rawValue: 0x10)
    public static let rightShift = KeyModifiers(rawValue: 0x20)
    public static let rightAlt = KeyModifiers(rawValue: 0x40)
    public static let rightGUI = KeyModifiers(rawValue: 0x80)
}

/// O que uma tecla faz. Cada entrada da matriz (comando 0x84/0x04, endereço 0xD4) tem 4 bytes.
///
/// Codificação reconstruída de FUN_0040c2a0 do KeyboardDrv.exe:
/// - tecla comum: `00 00 mods uso`
/// - modificador sozinho: `06 00 00 uso` (uso E0...E7)
/// - tecla de mídia: `04 00 usoAlto usoBaixo` (página Consumer)
/// - camada Fn: `02 .. .. slot` (o app não mexe)
/// - desativada: `00 00 00 00`
public enum KeyAction: Codable, Hashable, Sendable {
    case key(usage: UInt8, modifiers: KeyModifiers)
    case media(usage: UInt16)
    case disabled
    case other([UInt8])

    public static let size = 4
    static let keyboardType: UInt8 = 0x00
    static let fnType: UInt8 = 0x02
    static let mediaType: UInt8 = 0x04
    static let modifierType: UInt8 = 0x06

    public init(bytes: [UInt8]) {
        precondition(bytes.count == Self.size)
        switch bytes[0] {
        case Self.keyboardType where bytes == [0, 0, 0, 0]:
            self = .disabled
        case Self.keyboardType where bytes[1] == 0:
            self = .key(usage: bytes[3], modifiers: KeyModifiers(rawValue: bytes[2]))
        case Self.modifierType where bytes[1] == 0 && bytes[2] == 0 && (0xE0...0xE7).contains(bytes[3]):
            self = .key(usage: bytes[3], modifiers: [])
        case Self.mediaType where bytes[1] == 0:
            self = .media(usage: UInt16(bytes[2]) << 8 | UInt16(bytes[3]))
        default:
            self = .other(bytes)
        }
    }

    public var bytes: [UInt8] {
        switch self {
        case .key(let usage, let modifiers):
            if modifiers.isEmpty && (0xE0...0xE7).contains(usage) {
                return [Self.modifierType, 0, 0, usage]
            }
            return [Self.keyboardType, 0, modifiers.rawValue, usage]
        case .media(let usage):
            return [Self.mediaType, 0, UInt8(usage >> 8), UInt8(usage & 0xFF)]
        case .disabled:
            return [0, 0, 0, 0]
        case .other(let raw):
            return raw
        }
    }

    public var isFnLayer: Bool {
        if case .other(let raw) = self { return raw.first == Self.fnType }
        return false
    }

    public var displayName: String {
        switch self {
        case .key(let usage, let modifiers):
            var parts: [String] = []
            if modifiers.contains(.leftControl) || modifiers.contains(.rightControl) { parts.append("Ctrl") }
            if modifiers.contains(.leftAlt) || modifiers.contains(.rightAlt) { parts.append("Alt/⌥") }
            if modifiers.contains(.leftShift) || modifiers.contains(.rightShift) { parts.append("Shift") }
            if modifiers.contains(.leftGUI) || modifiers.contains(.rightGUI) { parts.append("Win/⌘") }
            parts.append(HIDKeyNames.name(usage))
            return parts.joined(separator: " + ")
        case .media(let usage):
            return MediaKey.all.first { $0.usage == usage }?.name ?? String(format: "Mídia 0x%04X", usage)
        case .disabled:
            return "Desativada"
        case .other(let raw):
            if raw.first == Self.fnType { return "Camada Fn" }
            return raw.map { String(format: "%02X", $0) }.joined(separator: " ")
        }
    }
}

public struct MediaKey: Identifiable, Hashable, Sendable {
    public let usage: UInt16
    public let name: String
    public var id: UInt16 { usage }

    /// As teclas de mídia que o driver oferece (tabela de FUN_0040c2a0).
    public static let all: [MediaKey] = [
        .init(usage: 0x00CD, name: "Tocar/Pausar"),
        .init(usage: 0x00B5, name: "Próxima faixa"),
        .init(usage: 0x00B6, name: "Faixa anterior"),
        .init(usage: 0x00B7, name: "Parar"),
        .init(usage: 0x00E9, name: "Volume +"),
        .init(usage: 0x00EA, name: "Volume −"),
        .init(usage: 0x00E2, name: "Mudo"),
        .init(usage: 0x0183, name: "Player de mídia"),
        .init(usage: 0x018A, name: "E-mail"),
        .init(usage: 0x0192, name: "Calculadora"),
        .init(usage: 0x0194, name: "Meu computador"),
        .init(usage: 0x0221, name: "Busca (navegador)"),
        .init(usage: 0x0223, name: "Página inicial"),
        .init(usage: 0x0224, name: "Voltar"),
        .init(usage: 0x0225, name: "Avançar"),
        .init(usage: 0x0226, name: "Parar página"),
        .init(usage: 0x0227, name: "Recarregar"),
        .init(usage: 0x022A, name: "Favoritos"),
    ]
}

public enum HIDKeyNames {
    public static let names: [UInt8: String] = {
        var n: [UInt8: String] = [:]
        for (i, c) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() { n[UInt8(0x04 + i)] = String(c) }
        for (i, c) in "1234567890".enumerated() { n[UInt8(0x1E + i)] = String(c) }
        for i in 0..<12 { n[UInt8(0x3A + i)] = "F\(i + 1)" }
        for i in 0..<12 { n[UInt8(0x68 + i)] = "F\(i + 13)" }
        let fixed: [UInt8: String] = [
            0x28: "Enter", 0x29: "Esc", 0x2A: "Backspace", 0x2B: "Tab", 0x2C: "Espaço",
            0x2D: "-", 0x2E: "=", 0x2F: "[", 0x30: "]", 0x31: "\\", 0x33: ";", 0x34: "'",
            0x35: "`", 0x36: ",", 0x37: ".", 0x38: "/", 0x39: "Caps Lock",
            0x46: "Print Screen", 0x47: "Scroll Lock", 0x48: "Pause", 0x49: "Insert",
            0x4A: "Home", 0x4B: "Page Up", 0x4C: "Delete", 0x4D: "End", 0x4E: "Page Down",
            0x4F: "→", 0x50: "←", 0x51: "↓", 0x52: "↑", 0x65: "Menu (Application)", 0x64: "\\ (ISO)",
            0xE0: "Ctrl esquerdo", 0xE1: "Shift esquerdo", 0xE2: "Alt/⌥ esquerdo", 0xE3: "Win/⌘ esquerdo",
            0xE4: "Ctrl direito", 0xE5: "Shift direito", 0xE6: "Alt/⌥ direito", 0xE7: "Win/⌘ direito",
        ]
        n.merge(fixed) { $1 }
        return n
    }()

    public static func name(_ usage: UInt8) -> String {
        names[usage] ?? String(format: "Tecla 0x%02X", usage)
    }

    /// Lista ordenada para o seletor de teclas.
    public static var sortedUsages: [UInt8] { names.keys.sorted() }
}
