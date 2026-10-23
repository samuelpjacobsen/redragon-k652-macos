import Foundation
import IOKit.hid

/// Relatório bruto, só de leitura, para descobrir por que uma leitura falha.
/// Usa apenas os comandos de consulta do driver (0x81, 0x83, 0x84); nada é gravado no teclado.
public enum K652Diagnostics {
    struct Probe {
        let title: String
        let command: [UInt8]
        let responseID: UInt8
        let delay: TimeInterval
    }

    static let probes: [Probe] = [
        Probe(title: "identidade 0x81 -> report 5", command: [5, 0x81, 0, 0, 0, 0], responseID: 5, delay: 0.02),
        Probe(title: "iluminação 0x83 @B6 -> report 6 (20 ms)", command: [5, 0x83, 0xB6, 0, 0, 0], responseID: 6, delay: 0.02),
        Probe(title: "iluminação 0x83 @B6 -> report 6 (200 ms)", command: [5, 0x83, 0xB6, 0, 0, 0], responseID: 6, delay: 0.2),
        Probe(title: "iluminação 0x83 @B6 -> report 5", command: [5, 0x83, 0xB6, 0, 0, 0], responseID: 5, delay: 0.02),
        Probe(title: "teclas 0x84 @D4 -> report 6 (20 ms)", command: [5, 0x84, 0xD4, 0, 0, 0], responseID: 6, delay: 0.02),
    ]
    static let shownBytes = K652Report.dataSize

    public static func run(transport: HIDTransport = HIDTransport()) -> String {
        var lines = ["diagnóstico K652 \(ISO8601DateFormatter().string(from: Date()))"]
        do {
            try transport.open()
        } catch {
            return (lines + ["abrir: \(error.localizedDescription)"]).joined(separator: "\n")
        }
        defer { transport.close() }
        lines.append("produto: \(transport.productName), firmware 0x\(String(transport.firmwareVersion, radix: 16))")
        lines += transport.interfaces.map { "interface: \($0)" }
        for probe in probes {
            lines.append("")
            lines.append("== \(probe.title)")
            lines += run(probe, on: transport)
        }
        return lines.joined(separator: "\n")
    }

    static func run(_ probe: Probe, on transport: HIDTransport) -> [String] {
        do {
            try transport.setFeature(probe.command)
        } catch {
            return ["envio: \(error.localizedDescription)"]
        }
        Thread.sleep(forTimeInterval: probe.delay)
        let (result, bytes) = transport.getFeatureRaw(probe.responseID)
        var lines = ["IOReturn 0x\(String(UInt32(bitPattern: result), radix: 16)), \(bytes.count) bytes"]
        guard result == kIOReturnSuccess else { return lines }
        lines.append(hexDump(Array(bytes.prefix(shownBytes))))
        if let at = signatureOffset(bytes) { lines.append("5A A5 no byte \(at)") }
        let nonZero = bytes.indices.filter { bytes[$0] != 0 }
        lines.append("bytes diferentes de zero: \(nonZero.count), último em \(nonZero.last ?? -1)")
        return lines
    }

    static func signatureOffset(_ bytes: [UInt8]) -> Int? {
        guard bytes.count > 1 else { return nil }
        return (0..<(bytes.count - 1)).first { bytes[$0] == 0x5A && bytes[$0 + 1] == 0xA5 }
    }

    static func hexDump(_ bytes: [UInt8]) -> String {
        stride(from: 0, to: bytes.count, by: 16).map { start in
            String(format: "%04d  ", start) + Array(bytes[start..<min(start + 16, bytes.count)]).hexString
        }.joined(separator: "\n")
    }
}
