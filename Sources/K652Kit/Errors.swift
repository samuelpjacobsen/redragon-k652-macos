import Foundation
import IOKit.hid

public enum K652Error: LocalizedError, Equatable {
    case notFound
    case accessDenied
    case openFailed(IOReturn)
    case reportNotSupported(UInt8)
    case setReportFailed(UInt8, IOReturn)
    case getReportFailed(UInt8, IOReturn)
    case badResponse(String)
    case remapFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Teclado K652 não encontrado pelo cabo USB."
        case .accessDenied:
            return "O macOS negou acesso ao teclado. Libere o app em Ajustes > Privacidade e Segurança > Monitoramento de Entrada."
        case .openFailed(let code):
            return "Não consegui abrir o teclado (IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16)))."
        case .reportNotSupported(let id):
            return "O teclado conectado não expõe o relatório HID \(id)."
        case .setReportFailed(let id, let code):
            return "Falha ao enviar o relatório \(id) (IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16)))."
        case .getReportFailed(let id, let code):
            return "Falha ao ler o relatório \(id) (IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16)))."
        case .badResponse(let detail):
            return "Resposta inesperada do teclado: \(detail)"
        case .remapFailed(let detail):
            return "O macOS recusou o remapeamento (hidutil): \(detail)"
        }
    }
}

extension K652Error {
    /// Códigos de uma referência a um dispositivo que sumiu do USB. O Azure pode reiniciar depois de
    /// aplicar a iluminação e volta como um dispositivo novo; a referência antiga responde
    /// MACH_SEND_INVALID_DEST.
    static let lostDeviceCodes: Set<IOReturn> = [
        IOReturn(bitPattern: 0x1000_0003), // MACH_SEND_INVALID_DEST
        kIOReturnNoDevice, kIOReturnNotOpen, kIOReturnNotAttached,
        kIOReturnOffline, kIOReturnAborted, kIOReturnNotResponding,
    ]

    public var isLostDevice: Bool {
        switch self {
        case .setReportFailed(_, let code), .getReportFailed(_, let code): return Self.lostDeviceCodes.contains(code)
        default: return false
        }
    }
}
