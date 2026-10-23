import Foundation

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
