import SwiftUI
import K652Kit

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
