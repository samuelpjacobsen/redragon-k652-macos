import Foundation

/// Bloco de configuração de iluminação (comando 0x83/0x03, 136 bytes no endereço 0xB6).
///
/// Layout reconstruído de FUN_0040d240 (construtor) e FUN_0040d3b0 (sincronização) do KeyboardDrv.exe:
/// - [0]: zerado pelo driver antes de gravar (OurCfg=0)
/// - [12]: 1 quando o modo ativo é o personalizado (`LedModeSelectOffset` = 4, a partir do byte 8).
///   No Azure, com 1 o teclado mostra as cores por tecla do grupo [14] qualquer que seja o [13]
///   (testado em 23/10/2026).
/// - [13]: modo de hardware (0 desligado, 1...21)
/// - [14]: 0x20 + grupo personalizado (0...4)
/// - [28], [29]: FF FF
/// - [30 + 2*(hw-1)]: cor (nibble baixo: índice da paleta, 7 = aleatório; nibble alto: direção 0/8)
/// - [31 + 2*(hw-1)]: nibble alto velocidade, nibble baixo brilho
/// - [70], [71]: assinatura 5A A5
/// Os demais bytes vêm do teclado e voltam intactos.
public struct LightingBlock: Equatable, Sendable {
    public static let size = 136
    public static let customFlagOffset = 12
    public static let modeOffset = 13
    public static let groupOffset = 14
    public static let fillerOffset = 28
    public static let perModeOffset = 30
    public static let signatureOffset = 70
    public static let signature: [UInt8] = [0x5A, 0xA5]
    public static let groupBase: UInt8 = 0x20
    public static let groupCount = 5
    static let directionReversed: UInt8 = 8

    public var bytes: [UInt8]

    public init(bytes: [UInt8]) {
        precondition(bytes.count == Self.size)
        self.bytes = bytes
    }

    public var hasSignature: Bool {
        Array(bytes[Self.signatureOffset..<Self.signatureOffset + 2]) == Self.signature
    }

    public var modeHW: UInt8 { bytes[Self.modeOffset] }

    public var customGroup: Int {
        let raw = Int(bytes[Self.groupOffset]) - Int(Self.groupBase)
        return (0..<Self.groupCount).contains(raw) ? raw : 0
    }

    static func perModeIndex(_ hw: UInt8) -> Int {
        Self.perModeOffset + 2 * (Int(hw) - 1)
    }

    /// Lê velocidade, brilho e cor de um modo. A paleta não é legível no teclado e vem de `palette`.
    public func settings(for hw: UInt8, palette: [LEDColor] = ModeSettings.defaultPalette) -> ModeSettings? {
        guard (1...LightingMode.lastStoredHW).contains(hw) else { return nil }
        let i = Self.perModeIndex(hw)
        let colorByte = bytes[i]
        let levelByte = bytes[i + 1]
        let colorIndex = Int(colorByte & 0x0F)
        return ModeSettings(
            speed: min(Int(levelByte >> 4), ModeSettings.levels.upperBound),
            brightness: min(Int(levelByte & 0x0F), ModeSettings.levels.upperBound),
            colorIndex: colorIndex >= ModeSettings.paletteSize ? 0 : colorIndex,
            random: colorIndex == ModeSettings.randomColorIndex,
            reversed: (colorByte >> 4) == Self.directionReversed,
            palette: palette
        )
    }

    /// Aplica o modo ativo e os ajustes por modo, só nos campos que cada modo usa.
    public mutating func apply(mode: LightingMode, group: Int, settings: [UInt8: ModeSettings]) {
        bytes[0] = 0
        bytes[Self.customFlagOffset] = mode.isCustom ? 1 : 0
        bytes[Self.modeOffset] = mode.hw
        bytes[Self.groupOffset] = Self.groupBase + UInt8(clamping: max(0, min(group, Self.groupCount - 1)))
        bytes[Self.fillerOffset] = 0xFF
        bytes[Self.fillerOffset + 1] = 0xFF
        for candidate in LightingMode.all where candidate.hasPerModeSettings {
            guard let s = settings[candidate.hw] else { continue }
            let i = Self.perModeIndex(candidate.hw)
            var colorByte = bytes[i]
            var levelByte = bytes[i + 1]
            if candidate.hasColor || candidate.hasRandom {
                let index = s.random ? ModeSettings.randomColorIndex : max(0, min(s.colorIndex, ModeSettings.paletteSize - 1))
                colorByte = (colorByte & 0xF0) | UInt8(index)
            }
            if candidate.hasDirection {
                colorByte = (s.reversed ? Self.directionReversed << 4 : 0) | (colorByte & 0x0F)
            }
            if candidate.hasSpeed {
                levelByte = UInt8(clamping: ModeSettings.levels.clamp(s.speed)) << 4 | (levelByte & 0x0F)
            }
            if candidate.hasBrightness {
                levelByte = (levelByte & 0xF0) | UInt8(clamping: ModeSettings.levels.clamp(s.brightness))
            }
            bytes[i] = colorByte
            bytes[i + 1] = levelByte
        }
        bytes[Self.signatureOffset] = Self.signature[0]
        bytes[Self.signatureOffset + 1] = Self.signature[1]
    }
}
