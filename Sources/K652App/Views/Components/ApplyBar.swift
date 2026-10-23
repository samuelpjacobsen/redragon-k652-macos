import SwiftUI
import K652Kit

/// Barra fixa no rodapé com o botão de gravar e o resultado da última operação.
struct ApplyBar: View {
    @EnvironmentObject var model: AppModel
    let title: String
    var enabled = true
    /// Falso quando a ação não fala com o teclado (o remapeamento do Bluetooth roda no Mac).
    var needsCable = true
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if model.busy {
                ProgressView().controlSize(.small)
                Text("Gravando…").foregroundStyle(.secondary)
            } else if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let message = model.message {
                Label(message, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }
            Spacer()
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled((needsCable && !model.canWrite) || model.busy || !enabled)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
