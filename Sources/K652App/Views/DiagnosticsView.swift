import SwiftUI
import AppKit
import K652Kit

struct DiagnosticsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("Teclado") {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        row("Estado", stateText)
                        row("USB", String(format: "VID 0x%04X  PID 0x%04X", HIDTransport.vendorID, HIDTransport.productID))
                        row("Bluetooth", String(format: "VID 0x%04X  PID 0x%04X (BT 5.0KB)", BluetoothKeyboard.vendorID, BluetoothKeyboard.productID))
                        if model.connection == .bluetooth {
                            row("Teclas trocadas no Mac", "\(HostKeyRemap.entries(model.hostRemaps).count)")
                        }
                        if let snap = model.snapshot {
                            row("Produto", snap.productName.isEmpty ? "—" : snap.productName)
                            row("Firmware", String(format: "0x%04X", snap.firmwareVersion))
                            row("Identificação", snap.identity.summary)
                            row("Assinatura 5A A5", snap.lighting?.hasSignature == true ? "presente" : "ausente")
                            if let error = snap.lightingError {
                                row("Leitura da iluminação", "falhou: \(error)")
                            }
                            row("Cores ao vivo", snap.supportsLivePreview ? "disponível (report 8)" : "indisponível")
                            ForEach(Array(snap.interfaces.enumerated()), id: \.offset) { item in
                                row(item.offset == 0 ? "Interfaces" : "", item.element)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .textSelection(.enabled)
                }

                if let snap = model.snapshot, !snap.looksLikeK652 {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("O app não confirmou que este é um K652.", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("O mesmo VID/PID da SinoWealth aparece em teclados com firmware diferente, e gravar o formato errado pode deixar o teclado sem resposta. Só libere se o modelo for mesmo o K652 RGB PRO.")
                                .font(.callout)
                            Toggle("Liberar gravação mesmo assim", isOn: $model.forceWrites)
                        }
                        .padding(6)
                    }
                }

                if let bytes = model.snapshot?.lighting?.bytes {
                    GroupBox("Bloco de iluminação (0x83 @ 0xB6)") {
                        Text(hexDump(bytes))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                    }
                }

                HStack {
                    Button("Reconectar") { model.connect() }
                    Button("Abrir Monitoramento de Entrada") {
                        if let url = ConnectionNotice.inputMonitoringSettings {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var stateText: String {
        switch model.connection {
        case .searching: return "Procurando (cabo USB ou Bluetooth)"
        case .bluetooth: return "Bluetooth: só teclas, mídia e energia. Iluminação e matriz de teclas exigem o cabo."
        case .connecting: return "Conectando…"
        case .connected: return "Conectado"
        case .needsPermission: return "Falta permissão de Monitoramento de Entrada"
        case .failed(let reason): return "Erro: \(reason)"
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func hexDump(_ bytes: [UInt8]) -> String {
        stride(from: 0, to: bytes.count, by: 16).map { start in
            String(format: "%03d  ", start) + Array(bytes[start..<min(start + 16, bytes.count)]).hexString
        }.joined(separator: "\n")
    }
}
