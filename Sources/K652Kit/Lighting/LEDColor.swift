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
