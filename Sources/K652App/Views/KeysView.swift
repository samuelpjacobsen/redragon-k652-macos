import SwiftUI
import K652Kit

private enum ActionKind: String, CaseIterable, Identifiable {
    case standard = "Padrão"
    case key = "Outra tecla"
    case media = "Mídia"
    case disabled = "Desativada"
    var id: String { rawValue }
}

struct KeysView: View {
    @EnvironmentObject var model: AppModel
    @ViewState private var selectedID: Int?

    private var selected: KeyDef? { K652Layout.keys.first { $0.id == selectedID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ConnectionNotice()
            if !model.keysAvailable {
                ContentUnavailableView("Matriz de teclas não lida",
                                       systemImage: "keyboard",
                                       description: Text("Conecte o K652 pelo cabo USB ou pelo Bluetooth."))
            } else {
                if model.keysOnMac {
                    Label("Pelo Bluetooth, a troca de teclas é feita pelo macOS e vale só neste Mac. Com o app aberto, ela volta sozinha quando o teclado reconecta.",
                          systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                KeyboardCanvas(
                    fill: { key in
                        if model.isPending(key) { return Color.orange.opacity(0.75) }
                        if model.isRemapped(key) { return Color.accentColor.opacity(0.55) }
                        return Color.secondary.opacity(0.18)
                    },
                    label: { key in
                        guard let action = model.action(for: key), isChanged(key, action) else { return key.label }
                        return "\(key.label)\n→ \(shortName(action))"
                    },
                    highlighted: { $0.id == selectedID },
                    dimmed: { !model.canEdit($0) },
                    onTouch: { key, isStart in
                        if isStart && key.hidUsage != nil { selectedID = key.id }
                    }
                )
                .frame(maxWidth: .infinity)

                HStack(spacing: 16) {
                    Label(model.keysOnMac ? "Trocada no Mac" : "Alterada no teclado", systemImage: "square.fill")
                        .foregroundStyle(Color.accentColor)
                    if !model.keysOnMac {
                        Label("Pendente (ainda não gravada)", systemImage: "square.fill").foregroundStyle(.orange)
                    }
                }
                .font(.caption)

                if let key = selected {
                    KeyEditor(key: key)
                        .id(key.id)
                } else {
                    Text(model.keysOnMac
                         ? "Escolha uma tecla para mudar o que ela faz. A tecla Fn não é remapeável."
                         : "Escolha uma tecla para mudar o que ela faz. As esmaecidas têm função com Fn (mídia, Bluetooth, luz) e ficam como estão.")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button("Restaurar todas ao padrão") { model.resetAllKeys() }
                    .disabled(!model.keysAvailable)
                if model.keysOnMac {
                    Toggle("Abrir ao iniciar sessão", isOn: Binding(get: { model.opensAtLogin },
                                                                     set: { model.setOpensAtLogin($0) }))
                        .help("Mantém o remapeamento depois de reiniciar o Mac")
                    ApplyBar(title: "Reaplicar no Mac", needsCable: false) { model.applyHostRemaps(announce: true) }
                } else {
                    Button("Descartar") { model.pendingKeys.removeAll() }
                        .disabled(model.pendingKeys.isEmpty)
                    Button("Reler do teclado") { model.readKeymap() }
                        .disabled(model.connection != .connected)
                    ApplyBar(title: "Gravar \(model.pendingKeys.count) alteração(ões)",
                             enabled: !model.pendingKeys.isEmpty, action: model.applyKeys)
                }
            }
            .padding(.leading, 20)
            .background(.bar)
        }
    }

    private func isChanged(_ key: KeyDef, _ action: KeyAction) -> Bool {
        guard let def = Keymap.defaultAction(for: key) else { return false }
        return action != def && !action.isFnLayer
    }

    private func shortName(_ action: KeyAction) -> String {
        if case .key(let usage, let mods) = action, mods.isEmpty { return HIDKeyNames.name(usage) }
        return action.displayName
    }
}

private struct KeyEditor: View {
    @EnvironmentObject var model: AppModel
    let key: KeyDef

    @ViewState private var kind: ActionKind = .standard
    @ViewState private var usage: UInt8 = 0x04
    @ViewState private var modifiers: KeyModifiers = []
    @ViewState private var media: UInt16 = MediaKey.all[0].usage

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Agora: \(model.action(for: key)?.displayName ?? "—")")
                    Spacer()
                    Text("Padrão: \(Keymap.defaultAction(for: key)?.displayName ?? "—")").foregroundStyle(.secondary)
                }
                if !model.canEdit(key) {
                    Text("Esta tecla tem uma função com Fn gravada no teclado. Trocar pelo cabo apagaria essa função sem como restaurar, então o app não mexe nela.")
                        .foregroundStyle(.secondary)
                } else {
                Picker("Ação", selection: $kind) {
                    ForEach(availableKinds) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 480)

                switch kind {
                case .key:
                    HStack {
                        Picker("Tecla", selection: $usage) {
                            ForEach(HIDKeyNames.sortedUsages, id: \.self) { Text(HIDKeyNames.name($0)).tag($0) }
                        }
                        .frame(maxWidth: 260)
                        if !model.keysOnMac {
                            modifierToggle("Ctrl", .leftControl)
                            modifierToggle("Shift", .leftShift)
                            modifierToggle("Alt/⌥", .leftAlt)
                            modifierToggle("Win/⌘", .leftGUI)
                        }
                    }
                case .media:
                    Picker("Mídia", selection: $media) {
                        ForEach(MediaKey.all) { Text($0.name).tag($0.usage) }
                    }
                    .frame(maxWidth: 300)
                case .standard, .disabled:
                    EmptyView()
                }

                Button("Usar nesta tecla") {
                    guard let action = chosenAction else { return }
                    model.setPending(action, for: key)
                }
                    .disabled(chosenAction == nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            Text("Tecla \(key.label)").font(.headline)
        }
        .onAppear(perform: loadCurrent)
    }

    /// O remapeamento do macOS não faz atalho com modificador nem desativa tecla.
    private var availableKinds: [ActionKind] {
        model.keysOnMac ? ActionKind.allCases.filter { $0 != .disabled } : ActionKind.allCases
    }

    private var chosenAction: KeyAction? {
        switch kind {
        case .standard: return Keymap.defaultAction(for: key)
        case .key: return .key(usage: usage, modifiers: model.keysOnMac ? [] : modifiers)
        case .media: return .media(usage: media)
        case .disabled: return .disabled
        }
    }

    private func modifierToggle(_ title: String, _ flag: KeyModifiers) -> some View {
        Toggle(title, isOn: Binding(
            get: { modifiers.contains(flag) },
            set: { isOn in
                if isOn { modifiers.insert(flag) } else { modifiers.remove(flag) }
            }
        ))
        .toggleStyle(.button)
    }

    private func loadCurrent() {
        guard let action = model.action(for: key) else { return }
        switch action {
        case .key(let u, let m):
            if action == Keymap.defaultAction(for: key) {
                kind = .standard
                usage = u
            } else {
                kind = .key
                usage = u
                modifiers = m
            }
        case .media(let u):
            kind = .media
            media = u
        case .disabled:
            kind = .disabled
        case .other:
            kind = .standard
        }
    }
}
