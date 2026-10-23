import CoreGraphics

/// Tecla física do K652 (84 teclas, layout 75%).
public struct KeyDef: Identifiable, Hashable, Sendable {
    public let id: Int
    public let label: String
    /// Posição na imagem do driver original (640 x 245).
    public let rect: CGRect
    public let windowsVK: Int
    /// Uso HID padrão da tecla; nil para a tecla Fn.
    public let hidUsage: UInt8?
    /// Índice do LED: coluna * 6 + linha (126 LEDs no total).
    public let ledIndex: Int
    /// Posição da tecla dentro de cada plano das cores salvas (0x09): último campo do [KEY], linha * 21
    /// + coluna. FUN_0043eed0 guarda esse campo em `DAT_005dcdcc`, e FUN_0040d3b0 grava a cor da tecla
    /// em `plano * 0x7E + DAT_005dcdcc`. Não é o LED: o ao vivo e a matriz de teclas usam `ledIndex`.
    public let customColorSlot: Int

    /// Posição na matriz de teclas (0x84): a mesma ordem dos LEDs. Conferido em 23/10/2026 com a
    /// matriz lida do Azure: nessa ordem, 52 teclas têm o uso HID padrão e 31 têm função Fn,
    /// enquanto pelo último campo do [KEY] do Cfg.ini só 1 batia.
    public var keymapSlot: Int { ledIndex }
}

public enum K652Layout {
    public static let ledCount = 126
    public static let canvasSize = CGSize(width: 630, height: 245)

    /// Gerado do [KEY] do Cfg.ini do instalador oficial V1.6.6.
    public static let keys: [KeyDef] = [
        KeyDef(id: 1, label: "Esc", rect: CGRect(x: 26, y: 15, width: 32, height: 32), windowsVK: 0x1B, hidUsage: 0x29, ledIndex: 0, customColorSlot: 0),
        KeyDef(id: 2, label: "F1", rect: CGRect(x: 63, y: 15, width: 32, height: 32), windowsVK: 0x70, hidUsage: 0x3A, ledIndex: 6, customColorSlot: 1),
        KeyDef(id: 3, label: "F2", rect: CGRect(x: 100, y: 15, width: 32, height: 32), windowsVK: 0x71, hidUsage: 0x3B, ledIndex: 12, customColorSlot: 2),
        KeyDef(id: 4, label: "F3", rect: CGRect(x: 135, y: 15, width: 32, height: 32), windowsVK: 0x72, hidUsage: 0x3C, ledIndex: 18, customColorSlot: 3),
        KeyDef(id: 5, label: "F4", rect: CGRect(x: 171, y: 15, width: 32, height: 32), windowsVK: 0x73, hidUsage: 0x3D, ledIndex: 24, customColorSlot: 4),
        KeyDef(id: 6, label: "F5", rect: CGRect(x: 208, y: 15, width: 32, height: 32), windowsVK: 0x74, hidUsage: 0x3E, ledIndex: 30, customColorSlot: 5),
        KeyDef(id: 7, label: "F6", rect: CGRect(x: 244, y: 15, width: 32, height: 32), windowsVK: 0x75, hidUsage: 0x3F, ledIndex: 36, customColorSlot: 6),
        KeyDef(id: 8, label: "F7", rect: CGRect(x: 281, y: 15, width: 32, height: 32), windowsVK: 0x76, hidUsage: 0x40, ledIndex: 42, customColorSlot: 7),
        KeyDef(id: 9, label: "F8", rect: CGRect(x: 317, y: 15, width: 32, height: 32), windowsVK: 0x77, hidUsage: 0x41, ledIndex: 48, customColorSlot: 8),
        KeyDef(id: 10, label: "F9", rect: CGRect(x: 353, y: 15, width: 32, height: 32), windowsVK: 0x78, hidUsage: 0x42, ledIndex: 54, customColorSlot: 9),
        KeyDef(id: 11, label: "F10", rect: CGRect(x: 390, y: 15, width: 32, height: 32), windowsVK: 0x79, hidUsage: 0x43, ledIndex: 60, customColorSlot: 10),
        KeyDef(id: 12, label: "F11", rect: CGRect(x: 427, y: 15, width: 32, height: 32), windowsVK: 0x7A, hidUsage: 0x44, ledIndex: 66, customColorSlot: 11),
        KeyDef(id: 13, label: "F12", rect: CGRect(x: 463, y: 15, width: 32, height: 32), windowsVK: 0x7B, hidUsage: 0x45, ledIndex: 72, customColorSlot: 12),
        KeyDef(id: 14, label: "Del", rect: CGRect(x: 571, y: 16, width: 32, height: 32), windowsVK: 0x2E, hidUsage: 0x4C, ledIndex: 90, customColorSlot: 15),
        KeyDef(id: 15, label: "`", rect: CGRect(x: 27, y: 51, width: 32, height: 32), windowsVK: 0xC0, hidUsage: 0x35, ledIndex: 1, customColorSlot: 21),
        KeyDef(id: 16, label: "1", rect: CGRect(x: 62, y: 51, width: 32, height: 32), windowsVK: 0x31, hidUsage: 0x1E, ledIndex: 7, customColorSlot: 22),
        KeyDef(id: 17, label: "2", rect: CGRect(x: 99, y: 51, width: 32, height: 32), windowsVK: 0x32, hidUsage: 0x1F, ledIndex: 13, customColorSlot: 23),
        KeyDef(id: 18, label: "3", rect: CGRect(x: 135, y: 51, width: 32, height: 32), windowsVK: 0x33, hidUsage: 0x20, ledIndex: 19, customColorSlot: 24),
        KeyDef(id: 19, label: "4", rect: CGRect(x: 172, y: 51, width: 32, height: 32), windowsVK: 0x34, hidUsage: 0x21, ledIndex: 25, customColorSlot: 25),
        KeyDef(id: 20, label: "5", rect: CGRect(x: 208, y: 51, width: 32, height: 32), windowsVK: 0x35, hidUsage: 0x22, ledIndex: 31, customColorSlot: 26),
        KeyDef(id: 21, label: "6", rect: CGRect(x: 244, y: 51, width: 32, height: 32), windowsVK: 0x36, hidUsage: 0x23, ledIndex: 37, customColorSlot: 27),
        KeyDef(id: 22, label: "7", rect: CGRect(x: 281, y: 51, width: 32, height: 32), windowsVK: 0x37, hidUsage: 0x24, ledIndex: 43, customColorSlot: 28),
        KeyDef(id: 23, label: "8", rect: CGRect(x: 317, y: 51, width: 32, height: 32), windowsVK: 0x38, hidUsage: 0x25, ledIndex: 49, customColorSlot: 29),
        KeyDef(id: 24, label: "9", rect: CGRect(x: 354, y: 51, width: 32, height: 32), windowsVK: 0x39, hidUsage: 0x26, ledIndex: 55, customColorSlot: 30),
        KeyDef(id: 25, label: "0", rect: CGRect(x: 390, y: 51, width: 32, height: 32), windowsVK: 0x30, hidUsage: 0x27, ledIndex: 61, customColorSlot: 31),
        KeyDef(id: 26, label: "-", rect: CGRect(x: 427, y: 51, width: 32, height: 32), windowsVK: 0xBD, hidUsage: 0x2D, ledIndex: 67, customColorSlot: 32),
        KeyDef(id: 27, label: "=", rect: CGRect(x: 463, y: 51, width: 32, height: 32), windowsVK: 0xBB, hidUsage: 0x2E, ledIndex: 73, customColorSlot: 33),
        KeyDef(id: 28, label: "⌫", rect: CGRect(x: 500, y: 51, width: 65, height: 32), windowsVK: 0x08, hidUsage: 0x2A, ledIndex: 79, customColorSlot: 34),
        KeyDef(id: 29, label: "Home", rect: CGRect(x: 571, y: 52, width: 32, height: 32), windowsVK: 0x24, hidUsage: 0x4A, ledIndex: 85, customColorSlot: 35),
        KeyDef(id: 30, label: "Tab", rect: CGRect(x: 27, y: 88, width: 46, height: 32), windowsVK: 0x09, hidUsage: 0x2B, ledIndex: 2, customColorSlot: 42),
        KeyDef(id: 31, label: "Q", rect: CGRect(x: 81, y: 88, width: 32, height: 32), windowsVK: 0x51, hidUsage: 0x14, ledIndex: 8, customColorSlot: 43),
        KeyDef(id: 32, label: "W", rect: CGRect(x: 117, y: 88, width: 32, height: 32), windowsVK: 0x57, hidUsage: 0x1A, ledIndex: 14, customColorSlot: 44),
        KeyDef(id: 33, label: "E", rect: CGRect(x: 153, y: 88, width: 32, height: 32), windowsVK: 0x45, hidUsage: 0x08, ledIndex: 20, customColorSlot: 45),
        KeyDef(id: 34, label: "R", rect: CGRect(x: 190, y: 88, width: 32, height: 32), windowsVK: 0x52, hidUsage: 0x15, ledIndex: 26, customColorSlot: 46),
        KeyDef(id: 35, label: "T", rect: CGRect(x: 227, y: 88, width: 32, height: 32), windowsVK: 0x54, hidUsage: 0x17, ledIndex: 32, customColorSlot: 47),
        KeyDef(id: 36, label: "Y", rect: CGRect(x: 262, y: 88, width: 32, height: 32), windowsVK: 0x59, hidUsage: 0x1C, ledIndex: 38, customColorSlot: 48),
        KeyDef(id: 37, label: "U", rect: CGRect(x: 299, y: 88, width: 32, height: 32), windowsVK: 0x55, hidUsage: 0x18, ledIndex: 44, customColorSlot: 49),
        KeyDef(id: 38, label: "I", rect: CGRect(x: 335, y: 88, width: 32, height: 32), windowsVK: 0x49, hidUsage: 0x0C, ledIndex: 50, customColorSlot: 50),
        KeyDef(id: 39, label: "O", rect: CGRect(x: 371, y: 88, width: 32, height: 32), windowsVK: 0x4F, hidUsage: 0x12, ledIndex: 56, customColorSlot: 51),
        KeyDef(id: 40, label: "P", rect: CGRect(x: 408, y: 88, width: 32, height: 32), windowsVK: 0x50, hidUsage: 0x13, ledIndex: 62, customColorSlot: 52),
        KeyDef(id: 41, label: "[", rect: CGRect(x: 444, y: 88, width: 32, height: 32), windowsVK: 0xDB, hidUsage: 0x2F, ledIndex: 68, customColorSlot: 53),
        KeyDef(id: 42, label: "]", rect: CGRect(x: 480, y: 88, width: 32, height: 32), windowsVK: 0xDD, hidUsage: 0x30, ledIndex: 74, customColorSlot: 54),
        KeyDef(id: 43, label: "\\", rect: CGRect(x: 519, y: 87, width: 46, height: 32), windowsVK: 0xDC, hidUsage: 0x31, ledIndex: 80, customColorSlot: 55),
        KeyDef(id: 44, label: "End", rect: CGRect(x: 572, y: 88, width: 32, height: 32), windowsVK: 0x23, hidUsage: 0x4D, ledIndex: 86, customColorSlot: 56),
        KeyDef(id: 45, label: "Caps", rect: CGRect(x: 27, y: 124, width: 56, height: 32), windowsVK: 0x14, hidUsage: 0x39, ledIndex: 3, customColorSlot: 63),
        KeyDef(id: 46, label: "A", rect: CGRect(x: 90, y: 124, width: 32, height: 32), windowsVK: 0x41, hidUsage: 0x04, ledIndex: 9, customColorSlot: 64),
        KeyDef(id: 47, label: "S", rect: CGRect(x: 127, y: 124, width: 32, height: 32), windowsVK: 0x53, hidUsage: 0x16, ledIndex: 15, customColorSlot: 65),
        KeyDef(id: 48, label: "D", rect: CGRect(x: 162, y: 124, width: 32, height: 32), windowsVK: 0x44, hidUsage: 0x07, ledIndex: 21, customColorSlot: 66),
        KeyDef(id: 49, label: "F", rect: CGRect(x: 200, y: 124, width: 32, height: 32), windowsVK: 0x46, hidUsage: 0x09, ledIndex: 27, customColorSlot: 67),
        KeyDef(id: 50, label: "G", rect: CGRect(x: 235, y: 124, width: 32, height: 32), windowsVK: 0x47, hidUsage: 0x0A, ledIndex: 33, customColorSlot: 68),
        KeyDef(id: 51, label: "H", rect: CGRect(x: 272, y: 124, width: 32, height: 32), windowsVK: 0x48, hidUsage: 0x0B, ledIndex: 39, customColorSlot: 69),
        KeyDef(id: 52, label: "J", rect: CGRect(x: 308, y: 124, width: 32, height: 32), windowsVK: 0x4A, hidUsage: 0x0D, ledIndex: 45, customColorSlot: 70),
        KeyDef(id: 53, label: "K", rect: CGRect(x: 344, y: 124, width: 32, height: 32), windowsVK: 0x4B, hidUsage: 0x0E, ledIndex: 51, customColorSlot: 71),
        KeyDef(id: 54, label: "L", rect: CGRect(x: 380, y: 124, width: 32, height: 32), windowsVK: 0x4C, hidUsage: 0x0F, ledIndex: 57, customColorSlot: 72),
        KeyDef(id: 55, label: ";", rect: CGRect(x: 417, y: 124, width: 32, height: 32), windowsVK: 0xBA, hidUsage: 0x33, ledIndex: 63, customColorSlot: 73),
        KeyDef(id: 56, label: "'", rect: CGRect(x: 454, y: 124, width: 32, height: 32), windowsVK: 0xDE, hidUsage: 0x34, ledIndex: 69, customColorSlot: 74),
        KeyDef(id: 57, label: "Enter", rect: CGRect(x: 492, y: 124, width: 72, height: 32), windowsVK: 0x0D, hidUsage: 0x28, ledIndex: 81, customColorSlot: 76),
        KeyDef(id: 58, label: "PgUp", rect: CGRect(x: 572, y: 124, width: 32, height: 32), windowsVK: 0x21, hidUsage: 0x4B, ledIndex: 87, customColorSlot: 77),
        KeyDef(id: 59, label: "Shift", rect: CGRect(x: 27, y: 160, width: 74, height: 32), windowsVK: 0xA0, hidUsage: 0xE1, ledIndex: 4, customColorSlot: 84),
        KeyDef(id: 60, label: "Z", rect: CGRect(x: 108, y: 160, width: 32, height: 32), windowsVK: 0x5A, hidUsage: 0x1D, ledIndex: 10, customColorSlot: 85),
        KeyDef(id: 61, label: "X", rect: CGRect(x: 144, y: 160, width: 32, height: 32), windowsVK: 0x58, hidUsage: 0x1B, ledIndex: 16, customColorSlot: 86),
        KeyDef(id: 62, label: "C", rect: CGRect(x: 181, y: 161, width: 32, height: 32), windowsVK: 0x43, hidUsage: 0x06, ledIndex: 22, customColorSlot: 87),
        KeyDef(id: 63, label: "V", rect: CGRect(x: 217, y: 160, width: 32, height: 32), windowsVK: 0x56, hidUsage: 0x19, ledIndex: 28, customColorSlot: 88),
        KeyDef(id: 64, label: "B", rect: CGRect(x: 253, y: 160, width: 32, height: 32), windowsVK: 0x42, hidUsage: 0x05, ledIndex: 34, customColorSlot: 89),
        KeyDef(id: 65, label: "N", rect: CGRect(x: 290, y: 160, width: 32, height: 32), windowsVK: 0x4E, hidUsage: 0x11, ledIndex: 40, customColorSlot: 90),
        KeyDef(id: 66, label: "M", rect: CGRect(x: 326, y: 160, width: 32, height: 32), windowsVK: 0x4D, hidUsage: 0x10, ledIndex: 46, customColorSlot: 91),
        KeyDef(id: 67, label: ",", rect: CGRect(x: 362, y: 160, width: 32, height: 32), windowsVK: 0xBC, hidUsage: 0x36, ledIndex: 52, customColorSlot: 92),
        KeyDef(id: 68, label: ".", rect: CGRect(x: 399, y: 160, width: 32, height: 32), windowsVK: 0xBE, hidUsage: 0x37, ledIndex: 58, customColorSlot: 93),
        KeyDef(id: 69, label: "/", rect: CGRect(x: 435, y: 160, width: 32, height: 32), windowsVK: 0xBF, hidUsage: 0x38, ledIndex: 64, customColorSlot: 94),
        KeyDef(id: 70, label: "Shift", rect: CGRect(x: 473, y: 160, width: 56, height: 32), windowsVK: 0xA1, hidUsage: 0xE5, ledIndex: 76, customColorSlot: 96),
        KeyDef(id: 71, label: "↑", rect: CGRect(x: 535, y: 161, width: 32, height: 32), windowsVK: 0x26, hidUsage: 0x52, ledIndex: 82, customColorSlot: 97),
        KeyDef(id: 72, label: "PgDn", rect: CGRect(x: 572, y: 161, width: 32, height: 32), windowsVK: 0x22, hidUsage: 0x4E, ledIndex: 88, customColorSlot: 98),
        KeyDef(id: 73, label: "Ctrl", rect: CGRect(x: 28, y: 197, width: 37, height: 32), windowsVK: 0xA2, hidUsage: 0xE0, ledIndex: 5, customColorSlot: 105),
        KeyDef(id: 74, label: "Win", rect: CGRect(x: 74, y: 197, width: 37, height: 32), windowsVK: 0x5B, hidUsage: 0xE3, ledIndex: 11, customColorSlot: 106),
        KeyDef(id: 75, label: "Alt", rect: CGRect(x: 121, y: 197, width: 37, height: 32), windowsVK: 0xA4, hidUsage: 0xE2, ledIndex: 17, customColorSlot: 107),
        KeyDef(id: 76, label: "Espaço", rect: CGRect(x: 164, y: 197, width: 220, height: 32), windowsVK: 0x20, hidUsage: 0x2C, ledIndex: 35, customColorSlot: 110),
        KeyDef(id: 77, label: "Alt", rect: CGRect(x: 390, y: 197, width: 32, height: 32), windowsVK: 0xA5, hidUsage: 0xE6, ledIndex: 53, customColorSlot: 113),
        KeyDef(id: 78, label: "Fn", rect: CGRect(x: 427, y: 196, width: 32, height: 32), windowsVK: 0xFA, hidUsage: nil, ledIndex: 59, customColorSlot: 114),
        KeyDef(id: 79, label: "←", rect: CGRect(x: 499, y: 197, width: 32, height: 32), windowsVK: 0x25, hidUsage: 0x50, ledIndex: 77, customColorSlot: 117),
        KeyDef(id: 80, label: "↓", rect: CGRect(x: 535, y: 197, width: 32, height: 32), windowsVK: 0x28, hidUsage: 0x51, ledIndex: 83, customColorSlot: 118),
        KeyDef(id: 81, label: "→", rect: CGRect(x: 572, y: 197, width: 32, height: 32), windowsVK: 0x27, hidUsage: 0x4F, ledIndex: 89, customColorSlot: 119),
        KeyDef(id: 82, label: "Ctrl", rect: CGRect(x: 463, y: 196, width: 32, height: 32), windowsVK: 0xA3, hidUsage: 0xE4, ledIndex: 65, customColorSlot: 115),
        KeyDef(id: 83, label: "PrtSc", rect: CGRect(x: 499, y: 15, width: 32, height: 32), windowsVK: 0x2C, hidUsage: 0x46, ledIndex: 78, customColorSlot: 13),
        KeyDef(id: 84, label: "Pause", rect: CGRect(x: 535, y: 15, width: 32, height: 32), windowsVK: 0x13, hidUsage: 0x48, ledIndex: 84, customColorSlot: 14),
    ]

    public static func key(windowsVK: Int) -> KeyDef? { keys.first { $0.windowsVK == windowsVK } }
}
