import Foundation

/// Comandos do protocolo SinoWealth usado pelo KeyboardDrv.exe (Redragon K652 RGB PRO, 0x258A:0x0049).
///
/// Leitura: o comando vai no feature report 5 (`05 cmd endereço 00 00 00`) e, 20 ms depois,
/// a resposta é lida no feature report 6 (`06 cmd endereço ... dados a partir do byte 8`).
/// Escrita: um feature report 6 de 0x408 bytes com o cabeçalho e os dados a partir do byte 8.
public enum K652Command: UInt8 {
    /// Identificação do modelo ("PSD"). A resposta vem no próprio report 5.
    case getIdentity = 0x81
    case getLighting = 0x83
    case getKeymap = 0x84
    case setLighting = 0x03
    case setKeymap = 0x04
    case setMacros = 0x05
    case setPaletteTable = 0x08
    case setCustomColors = 0x09
}

/// Endereços (páginas de 256 bytes na flash) com os valores padrão do driver, que o Cfg.ini do K652 não altera.
public enum K652Address {
    public static let lighting: UInt8 = 0xB6      // ProAddr
    public static let paletteTable: UInt8 = 0xB8  // RgbTabAddr
    public static let customColors: UInt8 = 0xBC  // GameAddr (+4 para o segundo bloco)
    public static let keymap: UInt8 = 0xD4        // KeyAddr
}

public enum K652Report {
    public static let command: UInt8 = 5
    public static let data: UInt8 = 6
    public static let music: UInt8 = 8
    public static let dataSize = 0x408
    /// Os dados do bloco começam depois de ID + 7 bytes de cabeçalho.
    public static let payloadOffset = 8
    public static let payloadCapacity = dataSize - payloadOffset
    /// Byte 4 dos blocos grandes (matriz, paleta, cores por tecla): 0x40, como o driver grava.
    public static let largeBlockMarker: UInt8 = 0x40
}

public final class K652Protocol {
    public let transport: HIDTransport
    /// Pausas entre gravações, iguais às do driver.
    static let writeGap: TimeInterval = 0.05

    public init(transport: HIDTransport = HIDTransport()) {
        self.transport = transport
    }

    /// Lê um bloco (0x83, 0x84). Devolve o feature report 6 completo.
    public func readBlock(_ command: K652Command, address: UInt8) throws -> [UInt8] {
        try transport.setFeature([K652Report.command, command.rawValue, address, 0, 0, 0])
        Thread.sleep(forTimeInterval: HIDTransport.responseDelay)
        let response = try transport.getFeature(K652Report.data)
        guard response.count > K652Report.payloadOffset else {
            throw K652Error.badResponse("bloco curto (\(response.count) bytes)")
        }
        guard response[1] == command.rawValue else {
            throw K652Error.badResponse(String(format: "esperava 0x%02X, veio 0x%02X", command.rawValue, response[1]))
        }
        return response
    }

    public func readPayload(_ command: K652Command, address: UInt8, length: Int) throws -> [UInt8] {
        let block = try readBlock(command, address: address)
        let end = K652Report.payloadOffset + length
        guard block.count >= end else { throw K652Error.badResponse("bloco com \(block.count) bytes") }
        return Array(block[K652Report.payloadOffset..<end])
    }

    /// Grava um bloco no report 6. `marker` é o byte 4 (0x40 nos blocos grandes, 0 na iluminação).
    public func writeBlock(_ command: K652Command, address: UInt8, marker: UInt8 = K652Report.largeBlockMarker, payload: [UInt8]) throws {
        try transport.setFeature(try Self.blockReport(command, address: address, marker: marker, payload: payload))
        Thread.sleep(forTimeInterval: Self.writeGap)
    }

    static func blockReport(_ command: K652Command, address: UInt8, marker: UInt8, payload: [UInt8]) throws -> [UInt8] {
        guard payload.count <= K652Report.payloadCapacity else {
            throw K652Error.badResponse("payload de \(payload.count) bytes não cabe no bloco")
        }
        var report = [UInt8](repeating: 0, count: K652Report.dataSize)
        report[0] = K652Report.data
        report[1] = command.rawValue
        report[2] = address
        report[4] = marker
        for (i, byte) in payload.enumerated() { report[K652Report.payloadOffset + i] = byte }
        return report
    }

    /// Identificação do modelo: resposta `05 01 p0 p1 p2 p3 ...`. O Cfg.ini do K652 espera PSD = 02 00 00 00 01 AB.
    public func readIdentity() throws -> [UInt8] {
        try transport.setFeature([K652Report.command, K652Command.getIdentity.rawValue, 0, 0, 0, 0])
        Thread.sleep(forTimeInterval: HIDTransport.responseDelay)
        return try transport.getFeature(K652Report.command)
    }
}
