import SwiftUI
import K652Kit

struct PerKeyView: View {
    @EnvironmentObject var model: AppModel
    @ViewState private var brush = Color(.sRGB, red: 0, green: 0.6, blue: 1)
    @ViewState private var eraser = false

    private let swatches: [LEDColor] = [
        LEDColor(255, 0, 0), LEDColor(255, 128, 0), LEDColor(255, 220, 0), LEDColor(0, 255, 0),
        LEDColor(0, 255, 200), LEDColor(0, 120, 255), LEDColor(140, 0, 255), LEDColor(255, 0, 180),
        .white,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ConnectionNotice()
            HStack(spacing: 12) {
                Picker("Grupo", selection: $model.group) {
                    ForEach(0..<LightingBlock.groupCount, id: \.self) { Text("\($0 + 1)").tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .help("Os 5 grupos de cores por tecla guardados no teclado")
                Spacer()
                Toggle("Pré-visualizar ao vivo", isOn: $model.livePreview)
                    .toggleStyle(.switch)
                    .fixedSize()
                    .disabled(model.connection != .connected || model.snapshot?.supportsLivePreview != true)
                    .help("Mostra as cores no teclado enquanto você pinta, sem gravar")
            }

            HStack(spacing: 10) {
                ColorPicker("Pincel", selection: $brush, supportsOpacity: false)
                    .fixedSize()
                    .onChange(of: brush) { eraser = false }
                ForEach(swatches, id: \.self) { swatch in
                    Button {
                        brush = swatch.color
                        eraser = false
                    } label: {
                        Circle().fill(swatch.color).frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(.separator))
                    }
                    .buttonStyle(.plain)
                }
                Toggle(isOn: $eraser) { Label("Borracha", systemImage: "eraser") }
                    .toggleStyle(.button)
                    .fixedSize()
                Spacer()
            }

            HStack(spacing: 8) {
                Button("Preencher tudo") { model.fillGroup(LEDColor(brush)) }
                Button("Apagar tudo") { model.fillGroup(.black) }
                Button("Padrão do grupo") { model.resetGroup() }
                Spacer()
            }

            KeyboardCanvas(
                fill: { key in (model.customGroups[safe: model.group]?[safe: key.ledIndex] ?? .black).color },
                onTouch: { key, _ in
                    model.paint(led: key.ledIndex, color: eraser ? .black : LEDColor(brush))
                },
                onEnd: { model.saveState() }
            )
            .frame(maxWidth: .infinity)

            Text("Clique ou arraste sobre as teclas para pintar. As cores ficam salvas no Mac e vão para o teclado ao gravar; o modo passa a ser Personalizado.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(20)
        .safeAreaInset(edge: .bottom) {
            ApplyBar(title: "Gravar e ativar", action: model.applyCustomColors)
        }
        .onDisappear { model.livePreview = false }
    }
}
