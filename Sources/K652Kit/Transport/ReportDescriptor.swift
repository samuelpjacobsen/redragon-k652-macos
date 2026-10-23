import Foundation

/// Leitura mínima de um descritor de relatórios HID (HID 1.11, seção 6.2.2).
///
/// O macOS só lista os elementos de um teclado para quem tem a permissão de Monitoramento de
/// Entrada, mas entrega o descritor bruto para qualquer processo. Lendo os tamanhos daqui, o app
/// reconhece o K652 antes da permissão e consegue dizer que é ela que falta.
public enum ReportDescriptor {
    static let longItemPrefix: UInt8 = 0xFE
    static let mainType: UInt8 = 0
    static let globalType: UInt8 = 1
    static let featureTag: UInt8 = 0x0B
    static let reportSizeTag: UInt8 = 0x07
    static let reportIDTag: UInt8 = 0x08
    static let reportCountTag: UInt8 = 0x09
    static let pushTag: UInt8 = 0x0A
    static let popTag: UInt8 = 0x0B

    private struct Globals {
        var reportSize = 0
        var reportCount = 0
        var reportID: UInt8 = 0
    }

    /// Tamanho total de cada feature report, contando o byte de ID, como o `HidP_GetCaps` do Windows.
    public static func featureReportSizes(_ descriptor: [UInt8]) -> [UInt8: Int] {
        var globals = Globals()
        var stack: [Globals] = []
        var bits: [UInt8: Int] = [:]
        var i = 0
        while i < descriptor.count {
            let prefix = descriptor[i]
            if prefix == longItemPrefix {
                guard i + 1 < descriptor.count else { break }
                i += 3 + Int(descriptor[i + 1])
                continue
            }
            let length = prefix & 0x03 == 3 ? 4 : Int(prefix & 0x03)
            guard i + length < descriptor.count else { break }
            let value = (0..<length).reduce(0) { $0 | Int(descriptor[i + 1 + $1]) << (8 * $1) }
            let type = (prefix >> 2) & 0x03
            let tag = prefix >> 4
            if type == mainType && tag == featureTag {
                bits[globals.reportID, default: 0] += globals.reportSize * globals.reportCount
            } else if type == globalType {
                switch tag {
                case reportSizeTag: globals.reportSize = value
                case reportCountTag: globals.reportCount = value
                case reportIDTag: globals.reportID = UInt8(truncatingIfNeeded: value)
                case pushTag: stack.append(globals)
                case popTag: globals = stack.popLast() ?? globals
                default: break
                }
            }
            i += 1 + length
        }
        var sizes: [UInt8: Int] = [:]
        for (id, total) in bits where total > 0 {
            sizes[id] = (total + 7) / 8 + (id == 0 ? 0 : 1)
        }
        return sizes
    }
}
