import Foundation

public enum IdentityStatus: Equatable, Sendable {
    case matches([UInt8])
    case mismatch([UInt8])
    case unavailable(String)

    public var summary: String {
        switch self {
        case .matches: return "K652 confirmado"
        case .mismatch(let bytes): return "Identificação diferente do K652: \(bytes.hexString)"
        case .unavailable(let reason): return "Sem identificação (\(reason))"
        }
    }
}

public struct DeviceSnapshot: Sendable {
    public let productName: String
    public let firmwareVersion: Int
    public let interfaces: [String]
    public let identity: IdentityStatus
    public let lighting: LightingBlock?
    public let lightingError: String?
    public let supportsLivePreview: Bool

    /// Só grava quando o modelo não diverge do K652 e o bloco de iluminação tem a assinatura 5A A5.
    public var looksLikeK652: Bool {
        if case .mismatch = identity { return false }
        return lighting?.hasSignature == true
    }
}
