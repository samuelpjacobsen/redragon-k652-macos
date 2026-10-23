import SwiftUI
import K652Kit

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
