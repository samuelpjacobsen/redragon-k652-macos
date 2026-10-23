import Foundation

/// Tabela de paletas (comando 0x08 no endereço 0xB8): 21 bytes zerados para o modo 0,
/// depois 7 cores RGB para cada modo, na ordem da lista do driver.
public enum PaletteTable {
    public static let entrySize = ModeSettings.paletteSize * 3

    public static func encode(_ settings: [UInt8: ModeSettings]) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: entrySize)
        for mode in LightingMode.all {
            let palette = settings[mode.hw]?.palette ?? ModeSettings.defaultPalette
            for slot in 0..<ModeSettings.paletteSize {
                let color = palette.indices.contains(slot) ? palette[slot] : .black
                data += [color.r, color.g, color.b]
            }
        }
        return data
    }
}
