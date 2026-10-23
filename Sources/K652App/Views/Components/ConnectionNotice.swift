import SwiftUI
import AppKit
import K652Kit

/// Aviso no topo das abas quando falta permissão ou o teclado está só no Bluetooth.
struct ConnectionNotice: View {
    @EnvironmentObject var model: AppModel

    static let inputMonitoringSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")

    var body: some View {
        if model.connection == .needsPermission {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("O teclado está no cabo, mas o macOS ainda não deixou o app falar com ele.",
                          systemImage: "lock.fill")
                        .font(.headline)
                    Text("Em Ajustes do Sistema › Privacidade e Segurança › Monitoramento de Entrada, ligue \"Teclado K652\". Se o macOS pedir para reabrir o app, aceite. O app conecta sozinho assim que a permissão sai.")
                        .font(.callout)
                    Button("Abrir Monitoramento de Entrada") {
                        if let url = Self.inputMonitoringSettings { NSWorkspace.shared.open(url) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
        } else if model.connection == .bluetooth {
            GroupBox {
                Label {
                    Text("Pelo Bluetooth o teclado não recebe comandos de iluminação: essa conexão só transmite as teclas. Ligue o cabo USB para gravar. Depois pode voltar ao Bluetooth, porque a configuração fica salva no teclado. Os atalhos com Fn do próprio teclado continuam funcionando sem cabo.")
                } icon: {
                    Image(systemName: "cable.connector")
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
        }
    }
}
