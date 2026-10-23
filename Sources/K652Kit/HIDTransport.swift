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

/// Uma interface HID do teclado e os relatórios de feature que ela declara.
public struct HIDInterfaceInfo: CustomStringConvertible {
    public let usagePage: Int
    public let usage: Int
    public let maxFeatureReportSize: Int
    /// Tamanho total (com o byte de ID) de cada relatório de feature, por ID.
    public let featureReportSizes: [UInt8: Int]

    public var description: String {
        let reports = featureReportSizes.keys.sorted()
            .map { "id \($0): \(featureReportSizes[$0]!) bytes" }
            .joined(separator: ", ")
        return String(format: "usagePage 0x%04X usage 0x%02X maxFeature %d [%@]",
                      usagePage, usage, maxFeatureReportSize, reports)
    }
}

/// Fala com o K652 por feature reports HID, como o KeyboardDrv.exe faz com HidD_SetFeature/HidD_GetFeature.
public final class HIDTransport {
    public static let vendorID = 0x258A
    public static let productID = 0x0049

    /// Tamanho total (com o ID) de cada feature report, como o KeyboardDrv.exe filtra as coleções HID:
    /// 6 bytes no canal de comando, 0x408 no de dados e 0x17E no do modo música.
    public static let knownReportSizes: [UInt8: Int] = [5: 6, 6: 0x408, 8: 0x17E]

    static let retryCount = 3
    static let retryDelay: TimeInterval = 0.2
    /// O driver original espera 20 ms entre o comando e a leitura da resposta.
    public static let responseDelay: TimeInterval = 0.02
    /// Depois de aplicar a iluminação o Azure pode sumir do USB por ~10 ms a ~2 s (log do kernel, 23/10/2026).
    static let reconnectTimeout: TimeInterval = 5
    static let reconnectPoll: TimeInterval = 0.25

    private var devicesByReport: [UInt8: IOHIDDevice] = [:]
    private var reportSizes: [UInt8: Int] = [:]
    private var openedDevices: [IOHIDDevice] = []
    public private(set) var interfaces: [HIDInterfaceInfo] = []
    public private(set) var firmwareVersion: Int = 0
    public private(set) var productName: String = ""

    public init() {}

    /// Um gerenciador novo a cada busca: um IOHIDManager fora de run loop não percebe que o
    /// teclado reconectou e continuaria devolvendo os dispositivos antigos.
    private static func currentDevices() -> Set<IOHIDDevice> {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [kIOHIDVendorIDKey: vendorID, kIOHIDProductIDKey: productID]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        return IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
    }

    deinit {
        close()
    }

    public var isOpen: Bool { !openedDevices.isEmpty }

    /// Pede ao macOS a permissão de Monitoramento de Entrada. No K652 os canais de configuração
    /// estão no mesmo dispositivo HID do teclado, e sem ela o `IOHIDDeviceOpen` devolve kIOReturnNotPermitted.
    @discardableResult
    public static func requestInputMonitoringAccess() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    public static var hasInputMonitoringAccess: Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    /// Procura as interfaces do teclado e abre as que têm relatórios de feature.
    public func open() throws {
        close()
        let set = Self.currentDevices()
        guard !set.isEmpty else { throw K652Error.notFound }
        var lastOpenError: IOReturn = kIOReturnSuccess
        for device in set {
            let info = Self.describe(device)
            interfaces.append(info)
            guard !info.featureReportSizes.isEmpty else { continue }
            let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
            guard result == kIOReturnSuccess else {
                lastOpenError = result
                continue
            }
            openedDevices.append(device)
            for (id, declared) in info.featureReportSizes where devicesByReport[id] == nil {
                devicesByReport[id] = device
                reportSizes[id] = Self.knownReportSizes[id] ?? declared
            }
            firmwareVersion = Self.intProperty(device, kIOHIDVersionNumberKey)
            productName = (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? ""
        }
        if openedDevices.isEmpty {
            if lastOpenError == kIOReturnNotPermitted || lastOpenError == kIOReturnNotPrivileged {
                throw K652Error.accessDenied
            }
            throw lastOpenError == kIOReturnSuccess ? K652Error.notFound : K652Error.openFailed(lastOpenError)
        }
    }

    public func close() {
        for device in openedDevices {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        openedDevices.removeAll()
        devicesByReport.removeAll()
        reportSizes.removeAll()
        interfaces.removeAll()
    }

    public func reportSize(_ id: UInt8) -> Int? { reportSizes[id] }

    /// Roda `body`; se o teclado tiver sumido do USB no meio do caminho, reabre e tenta mais uma vez.
    static func recoveringFromReset<T>(_ body: () throws -> T, reopen: () throws -> Void) throws -> T {
        do {
            return try body()
        } catch let error as K652Error where error.isLostDevice {
            try reopen()
            return try body()
        }
    }

    /// Espera o teclado voltar ao USB e reabre.
    func reopenAfterReset() throws {
        let deadline = Date().addingTimeInterval(Self.reconnectTimeout)
        var lastError: Error = K652Error.notFound
        repeat {
            Thread.sleep(forTimeInterval: Self.reconnectPoll)
            do {
                try open()
                return
            } catch {
                lastError = error
            }
        } while Date() < deadline
        throw lastError
    }

    /// Envia um feature report. `report[0]` é o ID; o restante é completado com zeros até o tamanho declarado.
    public func setFeature(_ report: [UInt8]) throws {
        try Self.recoveringFromReset({ try sendFeature(report) }, reopen: reopenAfterReset)
    }

    /// Lê um feature report. Devolve o relatório inteiro, com o ID no byte 0.
    public func getFeature(_ id: UInt8) throws -> [UInt8] {
        try Self.recoveringFromReset({ try receiveFeature(id) }, reopen: reopenAfterReset)
    }

    private func sendFeature(_ report: [UInt8]) throws {
        guard let id = report.first, let device = devicesByReport[id], let size = reportSizes[id] else {
            throw K652Error.reportNotSupported(report.first ?? 0)
        }
        var buffer = [UInt8](repeating: 0, count: size)
        for i in 0..<min(size, report.count) { buffer[i] = report[i] }
        var result: IOReturn = kIOReturnError
        for attempt in 0..<Self.retryCount {
            result = IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(id), buffer, buffer.count)
            if result == kIOReturnSuccess { return }
            if K652Error.lostDeviceCodes.contains(result) { break }
            if attempt < Self.retryCount - 1 { Thread.sleep(forTimeInterval: Self.retryDelay) }
        }
        throw K652Error.setReportFailed(id, result)
    }

    private func receiveFeature(_ id: UInt8) throws -> [UInt8] {
        guard let device = devicesByReport[id], let size = reportSizes[id] else {
            throw K652Error.reportNotSupported(id)
        }
        var result: IOReturn = kIOReturnError
        for attempt in 0..<Self.retryCount {
            var buffer = [UInt8](repeating: 0, count: size)
            buffer[0] = id
            var length = CFIndex(size)
            result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(id), &buffer, &length)
            if result == kIOReturnSuccess {
                return Self.normalizeFeature(Array(buffer.prefix(Int(length))), id: id)
            }
            if K652Error.lostDeviceCodes.contains(result) { break }
            if attempt < Self.retryCount - 1 { Thread.sleep(forTimeInterval: Self.retryDelay) }
        }
        throw K652Error.getReportFailed(id, result)
    }

    /// O teclado pode responder com menos bytes que o declarado: o 0x83 volta com 262 dos 1032.
    /// O relatório só é completado com o ID quando o IOKit o devolve sem esse byte.
    static func normalizeFeature(_ data: [UInt8], id: UInt8) -> [UInt8] {
        data.first == id ? data : [id] + data
    }

    /// Uma leitura sem tentativas nem ajustes, para diagnóstico: devolve o código e os bytes como vieram.
    public func getFeatureRaw(_ id: UInt8) -> (IOReturn, [UInt8]) {
        guard let device = devicesByReport[id], let size = reportSizes[id] else {
            return (kIOReturnUnsupported, [])
        }
        var buffer = [UInt8](repeating: 0, count: size)
        buffer[0] = id
        var length = CFIndex(size)
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, CFIndex(id), &buffer, &length)
        return (result, Array(buffer.prefix(max(0, Int(length)))))
    }

    // MARK: - Descrição das interfaces

    /// Os tamanhos vêm do descritor bruto, que o macOS entrega sem permissão; a lista de elementos
    /// só aparece depois do Monitoramento de Entrada e fica como reserva.
    static func describe(_ device: IOHIDDevice) -> HIDInterfaceInfo {
        var sizes: [UInt8: Int] = [:]
        if let descriptor = IOHIDDeviceGetProperty(device, kIOHIDReportDescriptorKey as CFString) as? Data {
            sizes = ReportDescriptor.featureReportSizes([UInt8](descriptor)).filter { $0.key != 0 }
        }
        let match = [kIOHIDElementTypeKey: kIOHIDElementTypeFeature.rawValue] as CFDictionary
        if sizes.isEmpty,
           let elements = IOHIDDeviceCopyMatchingElements(device, match, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement] {
            var bits: [UInt8: Int] = [:]
            for element in elements {
                let id = UInt8(truncatingIfNeeded: IOHIDElementGetReportID(element))
                bits[id, default: 0] += Int(IOHIDElementGetReportSize(element)) * Int(IOHIDElementGetReportCount(element))
            }
            for (id, total) in bits where id != 0 {
                sizes[id] = (total + 7) / 8 + 1
            }
        }
        return HIDInterfaceInfo(
            usagePage: intProperty(device, kIOHIDPrimaryUsagePageKey),
            usage: intProperty(device, kIOHIDPrimaryUsageKey),
            maxFeatureReportSize: intProperty(device, kIOHIDMaxFeatureReportSizeKey),
            featureReportSizes: sizes
        )
    }

    static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue ?? 0
    }
}
