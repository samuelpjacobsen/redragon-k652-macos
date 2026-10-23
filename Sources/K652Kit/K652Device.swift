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

/// Operações de alto nível, na mesma sequência que o KeyboardDrv.exe usa em FUN_0040d3b0.
/// Não é thread-safe: quem usa deve chamar sempre da mesma fila serial (o app usa `hidQueue`).
public final class K652Device: @unchecked Sendable {
    /// PSD do Cfg.ini do K652 (PSD=2,0,0,0,1,ab).
    public static let expectedIdentity: [UInt8] = [0x02, 0x00, 0x00, 0x00, 0x01, 0xAB]
    static let identityOK: UInt8 = 0x01

    public let proto: K652Protocol
    public var transport: HIDTransport { proto.transport }

    public init(proto: K652Protocol = K652Protocol()) {
        self.proto = proto
    }

    public func connect() throws -> DeviceSnapshot {
        try transport.open()
        let identity = readIdentityStatus()
        var lighting: LightingBlock?
        var lightingError: String?
        do {
            lighting = try readLighting()
        } catch {
            lightingError = error.localizedDescription
        }
        return DeviceSnapshot(
            productName: transport.productName,
            firmwareVersion: transport.firmwareVersion,
            interfaces: transport.interfaces.map(\.description),
            identity: identity,
            lighting: lighting,
            lightingError: lightingError,
            supportsLivePreview: transport.reportSize(K652Report.music) != nil
        )
    }

    public func disconnect() {
        transport.close()
    }

    func readIdentityStatus() -> IdentityStatus {
        do {
            let response = try proto.readIdentity()
            guard response.count >= 3, response[1] == Self.identityOK else {
                return .unavailable("resposta \(response.hexString)")
            }
            let psd = Array(response.dropFirst(2))
            let comparable = min(psd.count, Self.expectedIdentity.count)
            let matches = Array(psd.prefix(comparable)) == Array(Self.expectedIdentity.prefix(comparable))
            return matches ? .matches(psd) : .mismatch(psd)
        } catch {
            return .unavailable(error.localizedDescription)
        }
    }

    // MARK: - Iluminação

    public func readLighting() throws -> LightingBlock {
        let payload = try proto.readPayload(.getLighting, address: K652Address.lighting, length: LightingBlock.size)
        return LightingBlock(bytes: payload)
    }

    /// Lê o bloco atual, aplica o modo e os ajustes e grava paleta, cores por tecla e configuração.
    @discardableResult
    public func applyLighting(mode: LightingMode, group: Int, settings: [UInt8: ModeSettings],
                              customGroups: [[LEDColor]]?) throws -> LightingBlock {
        var block = try readLighting()
        Thread.sleep(forTimeInterval: HIDTransport.responseDelay)
        block.apply(mode: mode, group: group, settings: settings)
        if mode.isCustom {
            try writeCustomColors(customGroups ?? CustomColorMatrix.defaultGroups())
        } else {
            try proto.writeBlock(.setPaletteTable, address: K652Address.paletteTable, payload: PaletteTable.encode(settings))
        }
        try proto.writeBlock(.setLighting, address: K652Address.lighting, marker: 0, payload: block.bytes)
        return block
    }

    public func writeCustomColors(_ groups: [[LEDColor]]) throws {
        let chunks = CustomColorMatrix.chunks(CustomColorMatrix.encode(groups: groups))
        for (i, chunk) in chunks.enumerated() {
            try proto.writeBlock(.setCustomColors, address: K652Address.customColors + UInt8(4 * i), payload: chunk)
        }
    }

    /// Cores ao vivo, sem gravar na flash. O teclado volta ao efeito salvo quando os quadros param.
    public func sendLiveFrame(_ colors: [LEDColor]) throws {
        try transport.setFeature(DirectFrame.encode(colors))
    }

    // MARK: - Teclas

    public func readKeymap() throws -> Keymap {
        Keymap(bytes: try proto.readPayload(.getKeymap, address: K652Address.keymap, length: K652Report.payloadCapacity))
    }

    /// Lê a matriz, troca só as teclas pedidas (por `keymapSlot`) e grava de volta.
    @discardableResult
    public func applyKeyChanges(_ changes: [Int: KeyAction]) throws -> Keymap {
        var keymap = try readKeymap()
        guard keymap.looksLikeK652Keymap else {
            throw K652Error.badResponse("a matriz de teclas não está no formato esperado; nada foi gravado")
        }
        for slot in changes.keys {
            guard let key = K652Layout.keys.first(where: { $0.keymapSlot == slot }), keymap.canRemap(key) else {
                throw K652Error.badResponse("a tecla do slot \(slot) tem função Fn ou não existe; nada foi gravado")
            }
        }
        for (slot, action) in changes {
            keymap.set(action, slot: slot)
        }
        Thread.sleep(forTimeInterval: HIDTransport.responseDelay)
        try proto.writeBlock(.setKeymap, address: K652Address.keymap, payload: Array(keymap.bytes.prefix(0x400)))
        return keymap
    }
}

extension Array where Element == UInt8 {
    public var hexString: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}
