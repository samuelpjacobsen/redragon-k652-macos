import SwiftUI
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
