import Foundation

/// Matriz de teclas (1024 bytes): 132 entradas de 4 bytes, depois as matrizes da camada Fn.
public struct Keymap: Equatable {
    public static let entryCount = 0x84

    public var bytes: [UInt8]

    public init(bytes: [UInt8]) {
        precondition(bytes.count == K652Report.payloadCapacity || bytes.count >= Self.entryCount * KeyAction.size)
        self.bytes = bytes
    }

    /// Parte mínima das teclas que precisa estar no padrão ou com função Fn para o app aceitar gravar.
    static let minimumMatchingShare = 0.75

    public func action(slot: Int) -> KeyAction {
        let start = slot * KeyAction.size
        return KeyAction(bytes: Array(bytes[start..<start + KeyAction.size]))
    }

    public func action(for key: KeyDef) -> KeyAction { action(slot: key.keymapSlot) }

    public mutating func set(_ action: KeyAction, slot: Int) {
        let start = slot * KeyAction.size
        for (i, byte) in action.bytes.enumerated() { bytes[start + i] = byte }
    }

    /// Ação de fábrica de uma tecla: o próprio uso HID, sem modificadores.
    public static func defaultAction(for key: KeyDef) -> KeyAction? {
        key.hidUsage.map { .key(usage: $0, modifiers: []) }
    }

    /// Quantas teclas estão no seu lugar: com o próprio uso HID ou com função Fn (`02 00 00 nn`).
    /// Uma matriz lida na ordem errada quase não tem acertos, então isso confirma o formato antes de gravar.
    public func matchingKeyCount() -> Int {
        K652Layout.keys.filter { key in
            guard let def = Self.defaultAction(for: key) else { return false }
            let current = action(for: key)
            return current == def || current.isFnLayer
        }.count
    }

    public var looksLikeK652Keymap: Bool {
        let total = K652Layout.keys.filter { $0.hidUsage != nil }.count
        return Double(matchingKeyCount()) >= Double(total) * Self.minimumMatchingShare
    }

    /// Teclas com função Fn guardam um índice para a tabela da camada Fn. Trocar a entrada
    /// apagaria essa função (mídia, Bluetooth, iluminação) sem como restaurar, então o app não mexe nelas.
    public func canRemap(_ key: KeyDef) -> Bool {
        key.hidUsage != nil && !action(for: key).isFnLayer
    }
}
