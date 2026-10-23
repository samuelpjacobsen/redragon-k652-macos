import Foundation

public struct LEDColor: Codable, Hashable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    public static let black = LEDColor(0, 0, 0)
    public static let white = LEDColor(255, 255, 255)
    public static let blue = LEDColor(0, 0, 255)
}

/// Modo de iluminação de hardware, na ordem da lista do driver (LedOpt1...LedOpt22 do Cfg.ini).
public struct LightingMode: Identifiable, Hashable, Sendable {
    /// Valor gravado no byte de modo do bloco 0x83/0x03.
    public let hw: UInt8
    public let name: String
    public let hasSpeed: Bool
    public let hasBrightness: Bool
    public let hasDirection: Bool
    public let hasRandom: Bool
    public let hasColor: Bool
    /// O driver esconde o modo com LedMask=0x80000 (índice 19, "Perfect").
    public let hiddenByDriver: Bool

    public var id: UInt8 { hw }
    public var isCustom: Bool { hw == LightingMode.customHW }
    public var isOff: Bool { hw == 0 }
    public var hasPerModeSettings: Bool { (1...LightingMode.lastStoredHW).contains(hw) }

    public static let customHW: UInt8 = 21
    /// Os bytes por modo ocupam P[0x16...0x3D]; o modo 21 cai em cima da assinatura 5A A5.
    public static let lastStoredHW: UInt8 = 20

    // hw, nome, velocidade, brilho, direção, aleatório, cor  (colunas do LedOpt no Cfg.ini)
    public static let all: [LightingMode] = [
        .init(hw: 1, name: "Fixo", hasSpeed: false, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 2, name: "Respiração", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 3, name: "Arco-íris", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: false, hasColor: false, hiddenByDriver: false),
        .init(hw: 4, name: "Rastro ao digitar", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 5, name: "Gotas de chuva", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 6, name: "Roda arco-íris", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: false, hasColor: false, hiddenByDriver: false),
        .init(hw: 7, name: "Ondas ao digitar", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 8, name: "Estrelas piscando", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 9, name: "Sombra que some", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 10, name: "Cobrinha", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 11, name: "Neon", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 12, name: "Reação ao toque", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 13, name: "Onda senoidal", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 14, name: "Varredura", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 15, name: "Moinho girando", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: false, hasColor: false, hiddenByDriver: false),
        .init(hw: 16, name: "Cascata colorida", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: false, hasColor: false, hiddenByDriver: false),
        .init(hw: 17, name: "Florescer", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: false, hasColor: false, hiddenByDriver: false),
        .init(hw: 18, name: "Tempestade girando", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 19, name: "Colisão", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: false),
        .init(hw: 20, name: "Perfect", hasSpeed: true, hasBrightness: true, hasDirection: false, hasRandom: true, hasColor: true, hiddenByDriver: true),
        .init(hw: 21, name: "Personalizado (por tecla)", hasSpeed: false, hasBrightness: false, hasDirection: false, hasRandom: false, hasColor: false, hiddenByDriver: false),
        .init(hw: 0, name: "Desligado", hasSpeed: false, hasBrightness: false, hasDirection: false, hasRandom: false, hasColor: false, hiddenByDriver: false),
    ]

    public static var visible: [LightingMode] { all.filter { !$0.hiddenByDriver } }

    public static func mode(hw: UInt8) -> LightingMode? { all.first { $0.hw == hw } }
}

/// Ajustes de um modo de hardware. Velocidade e brilho vão de 0 a 4 (SpeedHW/LightHW = 0,1,2,3,4).
public struct ModeSettings: Codable, Hashable, Sendable {
    public static let levels = 0...4
    public static let paletteSize = 7
    /// Índice de cor que o firmware entende como "cores aleatórias" (RandomVal do driver).
    public static let randomColorIndex = 7

    public var speed: Int
    public var brightness: Int
    public var colorIndex: Int
    public var random: Bool
    public var reversed: Bool
    public var palette: [LEDColor]

    public init(speed: Int = 2, brightness: Int = 4, colorIndex: Int = 0, random: Bool = false,
                reversed: Bool = false, palette: [LEDColor] = ModeSettings.defaultPalette) {
        self.speed = speed
        self.brightness = brightness
        self.colorIndex = colorIndex
        self.random = random
        self.reversed = reversed
        self.palette = palette
    }

    public var selectedColor: LEDColor {
        palette.indices.contains(colorIndex) ? palette[colorIndex] : .white
    }

    /// Ajustes dentro dos limites do firmware, para valores vindos do disco.
    public func sanitized() -> ModeSettings {
        let slots = 0..<ModeSettings.paletteSize
        let fixedPalette = slots.map { palette.indices.contains($0) ? palette[$0] : ModeSettings.defaultPalette[$0] }
        return ModeSettings(
            speed: ModeSettings.levels.clamp(speed),
            brightness: ModeSettings.levels.clamp(brightness),
            colorIndex: slots.contains(colorIndex) ? colorIndex : 0,
            random: random,
            reversed: reversed,
            palette: fixedPalette
        )
    }

    /// Paleta padrão do driver (vermelho, azul, verde, roxo, amarelo, rosa, magenta).
    public static let defaultPalette: [LEDColor] = [
        LEDColor(0xFF, 0x00, 0x00), LEDColor(0x00, 0x00, 0xFF), LEDColor(0x00, 0xFF, 0x00),
        LEDColor(0x80, 0x00, 0xFF), LEDColor(0xFA, 0xC6, 0x03), LEDColor(0xFA, 0x03, 0x6A),
        LEDColor(0xFA, 0x00, 0xFA),
    ]
}

/// Bloco de configuração de iluminação (comando 0x83/0x03, 136 bytes no endereço 0xB6).
///
/// Layout reconstruído de FUN_0040d240 (construtor) e FUN_0040d3b0 (sincronização) do KeyboardDrv.exe:
/// - [0]: zerado pelo driver antes de gravar (OurCfg=0)
/// - [12]: 1 quando o modo ativo é o personalizado
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

/// Cores ao vivo (feature report 8: `08 0A 7A 01` + 126 LEDs em RGB intercalado), usado pelo modo música.
public enum DirectFrame {
    public static let header: [UInt8] = [K652Report.music, 0x0A, 0x7A, 0x01]

    public static func encode(_ colors: [LEDColor]) -> [UInt8] {
        var report = header + [UInt8](repeating: 0, count: K652Layout.ledCount * 3)
        for (led, color) in colors.prefix(K652Layout.ledCount).enumerated() {
            report[header.count + led * 3] = color.r
            report[header.count + led * 3 + 1] = color.g
            report[header.count + led * 3 + 2] = color.b
        }
        return report
    }
}

extension ClosedRange where Bound == Int {
    func clamp(_ value: Int) -> Int { Swift.max(lowerBound, Swift.min(upperBound, value)) }
}
