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
