import Foundation

/// Cores por tecla dos 5 grupos personalizados (comando 0x09 em 0xBC e 0xC0).
/// Cada grupo tem 3 planos de 0x7E bytes (R, G, B), indexados por `KeyDef.customColorSlot`
/// (FUN_0040d3b0). O app guarda as cores pelo LED; a troca de índice acontece só aqui.
public enum CustomColorMatrix {
    public static let planeSize = 0x7E
    public static let groupSize = planeSize * 3
    public static let chunkSize = 0x400

    public static func encode(groups: [[LEDColor]]) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: groupSize * LightingBlock.groupCount)
        for (g, colors) in groups.prefix(LightingBlock.groupCount).enumerated() {
            for key in K652Layout.keys where colors.indices.contains(key.ledIndex) {
                let color = colors[key.ledIndex]
                data[(3 * g + 0) * planeSize + key.customColorSlot] = color.r
                data[(3 * g + 1) * planeSize + key.customColorSlot] = color.g
                data[(3 * g + 2) * planeSize + key.customColorSlot] = color.b
            }
        }
        return data
    }

    /// `base` com o grupo `group` (0...4) inteiro numa cor só. Grupo fora da faixa devolve `base`.
    public static func filling(group: Int, with color: LEDColor, base: [[LEDColor]]) -> [[LEDColor]] {
        guard base.indices.contains(group) else { return base }
        var groups = base
        groups[group] = [LEDColor](repeating: color, count: K652Layout.ledCount)
        return groups
    }

    /// Os dois blocos de 1024 bytes que o driver grava em sequência.
    public static func chunks(_ data: [UInt8]) -> [[UInt8]] {
        stride(from: 0, to: data.count, by: chunkSize).map { start in
            var chunk = Array(data[start..<min(start + chunkSize, data.count)])
            chunk += [UInt8](repeating: 0, count: chunkSize - chunk.count)
            return chunk
        }
    }

    /// Grupos padrão do driver: GaoshouKey1...5 acesos em azul (clrGaoshou), o resto apagado.
    public static func defaultGroups() -> [[LEDColor]] {
        let groupsVK: [[Int]] = [
            [0x1B, 0x57, 0x41, 0x53, 0x44, 0x26, 0x28, 0x25, 0x27],
            [0x70, 0x71, 0x72, 0x31, 0x32, 0x33, 0x34, 0x35, 0x09, 0x51, 0x57, 0x45, 0x52, 0x41, 0x53, 0x44, 0x47, 0x10, 0x42, 0x11, 0x12, 0x20, 0x2C, 0x21, 0x22, 0x24, 0x23],
            [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x51, 0x57, 0x45, 0x52, 0x54, 0x41, 0x53, 0x44, 0x46, 0x47, 0x10, 0x43, 0x56, 0x11],
            [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x51, 0x57, 0x45, 0x52, 0x41, 0x53, 0x44, 0x46],
            [0x57, 0x52, 0x41, 0x53, 0x44, 0x10, 0x11, 0x12, 0x26, 0x28, 0x25, 0x27],
        ]
        return groupsVK.map { vks in
            var colors = [LEDColor](repeating: .black, count: planeSize)
            for vk in vks {
                // 0x10/0x11/0x12 no Cfg.ini são Shift/Ctrl/Alt genéricos: acende os dois lados.
                let generic: [Int: [Int]] = [0x10: [0xA0, 0xA1], 0x11: [0xA2, 0xA3], 0x12: [0xA4, 0xA5]]
                for code in generic[vk] ?? [vk] {
                    if let key = K652Layout.key(windowsVK: code) { colors[key.ledIndex] = .blue }
                }
            }
            return colors
        }
    }
}
