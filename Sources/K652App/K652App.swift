import SwiftUI
import AppKit
import K652Kit

@main
struct K652App: App {
    @StateObject private var model = AppModel()

    /// `--diagnostico <arquivo>`: grava as respostas brutas do teclado e sai, sem abrir janela.
    /// Roda dentro do app porque é ele que tem a permissão de Monitoramento de Entrada.
    init() {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--diagnostico"), flag + 1 < args.count else { return }
        let report = K652Diagnostics.run()
        do {
            try report.write(toFile: args[flag + 1], atomically: true, encoding: .utf8)
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("não gravei o diagnóstico: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    var body: some Scene {
        WindowGroup("Redragon Azure (K652)") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 860, minHeight: 620)
        }
        .windowResizability(.contentMinSize)
    }
}

enum Section: String, CaseIterable, Identifiable {
    case lighting = "Iluminação"
    case perKey = "Cores por tecla"
    case keys = "Teclas"
    case diagnostics = "Diagnóstico"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .lighting: return "sparkles"
        case .perKey: return "paintbrush.pointed"
        case .keys: return "keyboard"
        case .diagnostics: return "stethoscope"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    /// Lembra a última aba. Para abrir numa aba: `open -a "Teclado K652" --args --secao Teclas`.
    /// O argumento é lido à mão e só escolhe a aba inicial: com `-secao` (um traço) o macOS o trataria
    /// como preferência de prioridade máxima e a aba ficaria presa nele.
    @AppStorage("ultimaSecao") private var section: Section = .lighting

    static var launchSection: Section? {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--secao"), flag + 1 < args.count else { return nil }
        return Section(rawValue: args[flag + 1])
    }

    private var selection: Binding<Section?> {
        Binding(get: { section }, set: { if let value = $0 { section = value } })
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: selection) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .bottom) { ConnectionBadge().padding(12) }
        } detail: {
            Group {
                switch section {
                case .lighting: LightingView()
                case .perKey: PerKeyView()
                case .keys: KeysView()
                case .diagnostics: DiagnosticsView()
                }
            }
            .navigationTitle(section.rawValue)
        }
        .onAppear {
            if let start = Self.launchSection { section = start }
        }
        .onChange(of: section) {
            model.message = nil
            model.errorMessage = nil
        }
    }
}

struct ConnectionBadge: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout.weight(.medium))
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
            }
            Spacer(minLength: 0)
        }
    }

    private var color: Color {
        switch model.connection {
        case .connected: return model.snapshot?.looksLikeK652 == true ? .green : .orange
        case .bluetooth: return .blue
        case .connecting: return .yellow
        case .searching: return .gray
        case .needsPermission, .failed: return .red
        }
    }

    private var title: String {
        switch model.connection {
        case .connected: return "Azure pelo cabo"
        case .bluetooth: return "Azure por Bluetooth"
        case .connecting: return "Conectando…"
        case .searching: return "Sem teclado"
        case .needsPermission: return "Falta permissão"
        case .failed: return "Erro"
        }
    }

    private var detail: String? {
        switch model.connection {
        case .connected: return model.snapshot?.looksLikeK652 == true ? nil : "Modelo não confirmado"
        case .bluetooth: return "Iluminação só pelo cabo"
        case .searching: return "Ligue pelo cabo ou Bluetooth"
        case .needsPermission: return "Monitoramento de Entrada"
        case .failed(let reason): return reason
        case .connecting: return nil
        }
    }
}
