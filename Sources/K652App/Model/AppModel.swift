import Foundation
import SwiftUI
import K652Kit

/// O que o app guarda no disco: paleta e cores por tecla não podem ser lidas do teclado.
struct SavedState: Codable {
    var modeHW: UInt8 = 1
    var group: Int = 0
    var settings: [UInt8: ModeSettings] = [:]
    var customGroups: [[LEDColor]] = CustomColorMatrix.defaultGroups()
    /// Opcional para continuar lendo o estado salvo pelas versões sem Bluetooth.
    var hostRemaps: [UInt8: KeyAction]?
}

enum ConnectionState: Equatable {
    case searching
    case connecting
    case connected
    /// Ligado só pelo Bluetooth: dá para remapear teclas no Mac, mas não para configurar o teclado.
    case bluetooth
    case needsPermission
    case failed(String)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var connection: ConnectionState = .searching
    @Published var snapshot: DeviceSnapshot?
    @Published var busy = false
    @Published var message: String?
    @Published var errorMessage: String?
    @Published var forceWrites = false

    @Published var modeHW: UInt8 = 1
    @Published var group: Int = 0
    @Published var settings: [UInt8: ModeSettings] = [:]
    @Published var customGroups: [[LEDColor]] = CustomColorMatrix.defaultGroups()

    @Published var keymap: Keymap?
    @Published var pendingKeys: [Int: KeyAction] = [:]
    /// Remapeamento feito pelo macOS no teclado Bluetooth, por uso HID de origem.
    @Published var hostRemaps: [UInt8: KeyAction] = [:]

    @Published var livePreview = false {
        didSet { livePreview ? startLivePreview() : stopLivePreview() }
    }

    let device = K652Device()
    private let monitor = K652Monitor()
    let hidQueue = DispatchQueue(label: "k652.hid")
    private var liveTimer: Timer?
    private var pollTimer: Timer?
    static let liveFrameInterval: TimeInterval = 0.1
    static let presencePollInterval: TimeInterval = 3

    init() {
        loadState()
        monitor.onChange = { [weak self] in self?.refreshConnection(deviceChanged: true) }
        monitor.start()
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.presencePollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshConnection(deviceChanged: false) }
        }
        refreshConnection(deviceChanged: true)
    }

    var currentMode: LightingMode { LightingMode.mode(hw: modeHW) ?? LightingMode.all[0] }

    var canWrite: Bool {
        guard connection == .connected, let snapshot else { return false }
        return snapshot.looksLikeK652 || forceWrites
    }

    func binding(for hw: UInt8) -> Binding<ModeSettings> {
        Binding(
            get: { self.settings[hw] ?? ModeSettings() },
            set: { self.settings[hw] = $0; self.saveState() }
        )
    }

    // MARK: - Conexão

    /// Decide entre cabo e Bluetooth. O cabo tem prioridade porque é o único que aceita configuração.
    /// `deviceChanged` vem dos avisos de conexão. O Azure pode sumir e voltar no USB depois de gravar a
    /// iluminação (nem sempre), e a conexão antiga deixa de valer; o macOS também esquece o remapeamento
    /// do Bluetooth.
    func refreshConnection(deviceChanged: Bool) {
        if connection == .connecting { return }
        if connection == .needsPermission && monitor.usbPresent {
            if HIDTransport.hasInputMonitoringAccess { connect() }
            return
        }
        if monitor.usbPresent {
            if connection == .searching || connection == .bluetooth || deviceChanged { connect() }
            return
        }
        if connection != .searching && connection != .bluetooth { dropUSB() }
        guard monitor.bluetoothPresent else {
            connection = .searching
            return
        }
        let arrived = connection != .bluetooth
        connection = .bluetooth
        if arrived || deviceChanged { applyHostRemaps(announce: false) }
    }

    func connect() {
        guard connection != .connecting else { return }
        connection = .connecting
        hidQueue.async { [device] in
            let result = Result { try device.connect() }
            DispatchQueue.main.async { self.finishConnect(result) }
        }
    }

    private func finishConnect(_ result: Result<DeviceSnapshot, Error>) {
        switch result {
        case .success(let snap):
            snapshot = snap
            connection = .connected
            if let block = snap.lighting {
                adoptKeyboardState(block)
            }
            readKeymap()
        case .failure(K652Error.notFound):
            snapshot = nil
            connection = .searching
            // Com o USB ainda listado (teclado no meio de uma reconexão), a próxima tentativa fica com
            // a checagem periódica; chamar de novo aqui viraria um laço.
            if !monitor.usbPresent { refreshConnection(deviceChanged: true) }
        case .failure(K652Error.accessDenied):
            HIDTransport.requestInputMonitoringAccess()
            connection = .needsPermission
        case .failure(let error):
            connection = .failed(error.localizedDescription)
        }
    }

    private func dropUSB() {
        livePreview = false
        hidQueue.async { [device] in device.disconnect() }
        snapshot = nil
        keymap = nil
        pendingKeys.removeAll()
        connection = .searching
    }

    /// Modo, brilho, velocidade e cor vêm do teclado; a paleta e as cores por tecla, do disco.
    private func adoptKeyboardState(_ block: LightingBlock) {
        if LightingMode.mode(hw: block.modeHW) != nil { modeHW = block.modeHW }
        group = block.customGroup
        for mode in LightingMode.all {
            let palette = settings[mode.hw]?.palette ?? ModeSettings.defaultPalette
            if let fromKeyboard = block.settings(for: mode.hw, palette: palette) {
                settings[mode.hw] = fromKeyboard
            } else if settings[mode.hw] == nil {
                settings[mode.hw] = ModeSettings()
            }
        }
        saveState()
    }

    // MARK: - Gravação

    func runWrite(_ label: String, _ work: @escaping (K652Device) throws -> Void, done: (() -> Void)? = nil) {
        guard canWrite else {
            errorMessage = "Gravação bloqueada: o teclado não foi confirmado como K652. Veja a aba Diagnóstico."
            return
        }
        busy = true
        message = nil
        errorMessage = nil
        hidQueue.async { [device] in
            let result = Result { try work(device) }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success:
                    self.message = label
                    done?()
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func applyLighting() {
        let mode = currentMode
        let group = group
        let settings = settings
        let custom = customGroups
        saveState()
        runWrite("\(mode.name) gravado no teclado") { device in
            try device.applyLighting(mode: mode, group: group, settings: settings, customGroups: custom)
        }
    }

    func applyCustomColors() {
        modeHW = LightingMode.customHW
        applyLighting()
    }

    // MARK: - Cores por tecla

    func paint(led: Int, color: LEDColor) {
        guard customGroups.indices.contains(group), customGroups[group].indices.contains(led) else { return }
        guard customGroups[group][led] != color else { return }
        customGroups[group][led] = color
    }

    func fillGroup(_ color: LEDColor) {
        customGroups = CustomColorMatrix.filling(group: group, with: color, base: customGroups)
        saveState()
    }

    func resetGroup() {
        customGroups[group] = CustomColorMatrix.defaultGroups()[group]
        saveState()
    }

    private func startLivePreview() {
        guard connection == .connected, snapshot?.supportsLivePreview == true else {
            livePreview = false
            return
        }
        liveTimer?.invalidate()
        liveTimer = Timer.scheduledTimer(withTimeInterval: Self.liveFrameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sendLiveFrame() }
        }
    }

    private func stopLivePreview() {
        liveTimer?.invalidate()
        liveTimer = nil
    }

    private func sendLiveFrame() {
        guard customGroups.indices.contains(group) else { return }
        let colors = customGroups[group]
        hidQueue.async { [device] in
            do {
                try device.sendLiveFrame(colors)
            } catch {
                DispatchQueue.main.async {
                    self.livePreview = false
                    self.errorMessage = "Pré-visualização parou: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Disco

    private static var stateURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Teclado K652", isDirectory: true).appendingPathComponent("estado.json")
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: Self.stateURL) else { return }
        do {
            let state = try JSONDecoder().decode(SavedState.self, from: data)
            if LightingMode.mode(hw: state.modeHW) != nil { modeHW = state.modeHW }
            if (0..<LightingBlock.groupCount).contains(state.group) { group = state.group }
            settings = state.settings
                .filter { LightingMode.mode(hw: $0.key) != nil }
                .mapValues { $0.sanitized() }
            hostRemaps = Self.validHostRemaps(state.hostRemaps ?? [:])
            if state.customGroups.count == LightingBlock.groupCount,
               state.customGroups.allSatisfy({ $0.count == K652Layout.ledCount }) {
                customGroups = state.customGroups
            }
        } catch {
            errorMessage = "Ignorei o estado salvo (\(error.localizedDescription))."
        }
    }

    func saveState() {
        let state = SavedState(modeHW: modeHW, group: group, settings: settings, customGroups: customGroups,
                               hostRemaps: hostRemaps)
        do {
            let url = Self.stateURL
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: url, options: .atomic)
        } catch {
            errorMessage = "Não salvei o estado: \(error.localizedDescription)"
        }
    }
}
