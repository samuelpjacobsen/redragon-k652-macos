import Foundation

/// O K652 por Bluetooth, visto pelo macOS como "BT 5.0KB" (módulo BEKEN).
///
/// O descritor HID dessa conexão (153 bytes, lido em 23/10/2026) só declara teclado (reports 1 e 2),
/// mídia (3) e energia (4), e o único report de saída é o dos LEDs de Caps/Num Lock. Não há feature
/// reports nem a página vendor 0xFF00, então iluminação e matriz de teclas só mudam pelo cabo USB.
/// O KeyboardDrv.exe também só procura o USB (258A:0049).
public enum BluetoothKeyboard {
    public static let vendorID = 0x000E
    public static let productID = 0x3412

    public static var matchingJSON: String {
        #"{"VendorID":\#(vendorID),"ProductID":\#(productID)}"#
    }
}

/// Remapeamento de teclas feito pelo macOS (`hidutil` UserKeyMapping) só no teclado Bluetooth.
///
/// Nada é gravado no teclado: vale enquanto ele estiver ligado a este Mac, e o macOS esquece o
/// mapeamento quando o teclado reconecta, por isso o app reaplica a cada conexão.
public enum HostKeyRemap {
    public struct Entry: Equatable, Sendable {
        public let source: UInt64
        public let destination: UInt64
    }

    static let keyboardPage: UInt64 = 0x07
    static let consumerPage: UInt64 = 0x0C
    static let usagePageShift: UInt64 = 32

    /// O hidutil troca um uso HID por outro. Atalho com modificador e tecla desativada ficam de fora.
    public static func supports(_ action: KeyAction) -> Bool {
        switch action {
        case .key(_, let modifiers): return modifiers.isEmpty
        case .media: return true
        case .disabled, .other: return false
        }
    }

    public static func entries(_ remaps: [UInt8: KeyAction]) -> [Entry] {
        remaps.keys.sorted().compactMap { source in
            guard let action = remaps[source], let destination = usage(of: action) else { return nil }
            let from = keyboardPage << usagePageShift | UInt64(source)
            guard from != destination else { return nil }
            return Entry(source: from, destination: destination)
        }
    }

    public static func propertyJSON(_ entries: [Entry]) -> String {
        let items = entries.map {
            #"{"HIDKeyboardModifierMappingSrc":\#($0.source),"HIDKeyboardModifierMappingDst":\#($0.destination)}"#
        }
        return #"{"UserKeyMapping":[\#(items.joined(separator: ","))]}"#
    }

    private static func usage(of action: KeyAction) -> UInt64? {
        guard supports(action) else { return nil }
        switch action {
        case .key(let usage, _): return keyboardPage << usagePageShift | UInt64(usage)
        case .media(let usage): return consumerPage << usagePageShift | UInt64(usage)
        case .disabled, .other: return nil
        }
    }
}

/// Aplica o remapeamento com `/usr/bin/hidutil`, que não precisa de root para UserKeyMapping.
public enum HIDUtil {
    static let executable = URL(fileURLWithPath: "/usr/bin/hidutil")

    public static func setUserKeyMapping(_ entries: [HostKeyRemap.Entry], matching: String = BluetoothKeyboard.matchingJSON) throws {
        let process = Process()
        let errors = Pipe()
        process.executableURL = executable
        process.arguments = ["property", "--matching", matching, "--set", HostKeyRemap.propertyJSON(entries)]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw K652Error.remapFailed(detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
