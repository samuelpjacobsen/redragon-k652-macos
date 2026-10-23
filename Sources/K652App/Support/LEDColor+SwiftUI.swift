import SwiftUI
import AppKit
import K652Kit

extension LEDColor {
    var color: Color { Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255) }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(UInt8(clamping: Int((ns.redComponent * 255).rounded())),
                  UInt8(clamping: Int((ns.greenComponent * 255).rounded())),
                  UInt8(clamping: Int((ns.blueComponent * 255).rounded())))
    }

    /// Luminância aproximada, para escolher texto claro ou escuro sobre a tecla.
    var isLight: Bool { (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) > 150 }
}
