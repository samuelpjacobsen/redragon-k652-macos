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

/// Desenha as 84 teclas nas posições do driver original e repassa toques/arrastos.
struct KeyboardCanvas: View {
    var fill: (KeyDef) -> Color
    var label: (KeyDef) -> String = { $0.label }
    var highlighted: (KeyDef) -> Bool = { _ in false }
    var dimmed: (KeyDef) -> Bool = { _ in false }
    var onTouch: ((KeyDef, _ isStart: Bool) -> Void)?
    var onEnd: (() -> Void)?

    private let size = K652Layout.canvasSize

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / size.width, geo.size.height / size.height)
            let offset = CGPoint(x: (geo.size.width - size.width * scale) / 2,
                                 y: (geo.size.height - size.height * scale) / 2)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14 * scale)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 14 * scale).stroke(.separator))
                    .frame(width: size.width * scale, height: size.height * scale)
                ForEach(K652Layout.keys) { key in
                    keyView(key, scale: scale)
                        .frame(width: key.rect.width * scale, height: key.rect.height * scale)
                        .offset(x: key.rect.minX * scale, y: key.rect.minY * scale)
                }
            }
            .offset(x: offset.x, y: offset.y)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = CGPoint(x: (value.location.x - offset.x) / scale,
                                            y: (value.location.y - offset.y) / scale)
                        if let key = K652Layout.keys.first(where: { $0.rect.insetBy(dx: -2, dy: -2).contains(point) }) {
                            onTouch?(key, value.translation == .zero)
                        }
                    }
                    .onEnded { _ in onEnd?() }
            )
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
    }

    @ViewBuilder
    private func keyView(_ key: KeyDef, scale: CGFloat) -> some View {
        let color = fill(key)
        let isHighlighted = highlighted(key)
        RoundedRectangle(cornerRadius: 5 * scale)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 5 * scale)
                    .strokeBorder(isHighlighted ? Color.accentColor : Color.primary.opacity(0.18),
                                  lineWidth: isHighlighted ? 3 * scale : 1)
            )
            .overlay(
                Text(label(key))
                    .font(.system(size: max(7, 10 * scale), weight: .medium))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(2)
                    .foregroundStyle(LEDColor(color).isLight ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
            )
            .opacity(dimmed(key) ? 0.35 : 1)
    }
}
