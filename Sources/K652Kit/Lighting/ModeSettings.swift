import Foundation

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

extension ClosedRange where Bound == Int {
    func clamp(_ value: Int) -> Int { Swift.max(lowerBound, Swift.min(upperBound, value)) }
}
