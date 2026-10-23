import SwiftUI
import K652Kit

struct LightingView: View {
    @EnvironmentObject var model: AppModel
    @ViewState private var editingSlot = 0

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ConnectionNotice()
                preview
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)

                Text("Efeito").font(.headline)
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(LightingMode.visible) { mode in
                        Button {
                            model.modeHW = mode.hw
                            editingSlot = model.settings[mode.hw]?.colorIndex ?? 0
                        } label: {
                            Text(mode.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(model.modeHW == mode.hw ? Color.accentColor : Color.secondary.opacity(0.12))
                                )
                                .foregroundStyle(model.modeHW == mode.hw ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                settingsPanel
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            ApplyBar(title: "Aplicar no teclado", action: model.applyLighting)
        }
    }

    // MARK: - Prévia

    private var preview: some View {
        let mode = model.currentMode
        let s = model.settings[mode.hw] ?? ModeSettings()
        let level = mode.hasBrightness ? 0.25 + 0.1875 * Double(s.brightness) : 1
        return KeyboardCanvas(fill: { key in
            if mode.isOff { return Color.black.opacity(0.85) }
            if mode.isCustom {
                let colors = model.customGroups[safe: model.group] ?? []
                return (colors[safe: key.ledIndex] ?? .black).color
            }
            if (mode.hasColor || mode.hasRandom) && !s.random {
                return s.selectedColor.color.opacity(level)
            }
            let hue = Double(key.ledIndex / 6) / 21
            return Color(hue: hue, saturation: 0.85, brightness: 1).opacity(level)
        })
        .frame(maxHeight: 240)
    }

    // MARK: - Ajustes

    @ViewBuilder
    private var settingsPanel: some View {
        let mode = model.currentMode
        let s = model.binding(for: mode.hw)
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                if mode.isOff {
                    Text("A iluminação fica apagada.").foregroundStyle(.secondary)
                } else if mode.isCustom {
                    Picker("Grupo", selection: $model.group) {
                        ForEach(0..<LightingBlock.groupCount, id: \.self) { Text("Personalizado \($0 + 1)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("As cores de cada tecla ficam na aba Cores por tecla.")
                        .foregroundStyle(.secondary)
                } else {
                    if mode.hasBrightness {
                        LevelSlider(title: "Brilho", low: "Fraco", high: "Forte", value: s.brightness)
                    }
                    if mode.hasSpeed {
                        LevelSlider(title: "Velocidade", low: "0", high: "4", value: s.speed)
                    }
                    if mode.hasDirection {
                        Toggle("Inverter direção", isOn: s.reversed)
                    }
                    if mode.hasColor || mode.hasRandom {
                        colorPanel(mode: mode, s: s)
                    }
                    if !mode.hasColor && !mode.hasRandom {
                        Text("Este efeito usa as cores do próprio teclado.").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Text(mode.name).font(.headline)
        }
    }

    @ViewBuilder
    private func colorPanel(mode: LightingMode, s: Binding<ModeSettings>) -> some View {
        if mode.hasRandom {
            Toggle("Cores aleatórias", isOn: s.random)
        }
        if mode.hasColor {
            HStack(spacing: 10) {
                Text("Cor").frame(width: 80, alignment: .leading)
                ForEach(0..<ModeSettings.paletteSize, id: \.self) { slot in
                    let color = s.wrappedValue.palette[safe: slot] ?? .black
                    Button {
                        s.wrappedValue.colorIndex = slot
                        editingSlot = slot
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().strokeBorder(.separator))
                            .overlay(
                                Circle().stroke(Color.accentColor, lineWidth: 3).padding(-4)
                                    .opacity(s.wrappedValue.colorIndex == slot && !s.wrappedValue.random ? 1 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Usar esta cor")
                }
                ColorPicker("Editar", selection: Binding(
                    get: { (s.wrappedValue.palette[safe: s.wrappedValue.colorIndex] ?? .white).color },
                    set: { newColor in
                        var value = s.wrappedValue
                        if value.palette.indices.contains(value.colorIndex) {
                            value.palette[value.colorIndex] = LEDColor(newColor)
                        }
                        s.wrappedValue = value
                    }
                ), supportsOpacity: false)
                .help("Muda a cor selecionada da paleta")
            }
            .disabled(s.wrappedValue.random)
            .opacity(s.wrappedValue.random ? 0.4 : 1)
        }
    }
}
