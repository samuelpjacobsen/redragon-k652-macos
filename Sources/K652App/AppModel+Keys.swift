import Foundation
import ServiceManagement
import K652Kit

/// Teclas: pelo cabo, a matriz gravada no teclado; pelo Bluetooth, o remapeamento do macOS.
extension AppModel {
    /// Pelo Bluetooth o teclado não aceita a matriz de teclas, então o remapeamento fica no Mac.
    var keysOnMac: Bool { connection == .bluetooth }

    var keysAvailable: Bool { keysOnMac || keymap != nil }

    func action(for key: KeyDef) -> KeyAction? {
        if keysOnMac {
            guard let usage = key.hidUsage else { return nil }
            return hostRemaps[usage] ?? Keymap.defaultAction(for: key)
        }
        return pendingKeys[key.keymapSlot] ?? keymap?.action(for: key)
    }

    /// Pelo cabo, teclas com função Fn ficam de fora (ver `Keymap.canRemap`).
    func canEdit(_ key: KeyDef) -> Bool {
        guard key.hidUsage != nil else { return false }
        return keysOnMac || keymap?.canRemap(key) == true
    }

    func isPending(_ key: KeyDef) -> Bool {
        !keysOnMac && pendingKeys[key.keymapSlot] != nil
    }

    /// Tecla que já faz outra coisa: no teclado (cabo) ou no Mac (Bluetooth).
    func isRemapped(_ key: KeyDef) -> Bool {
        if keysOnMac { return key.hidUsage.map { hostRemaps[$0] != nil } ?? false }
        guard let current = keymap?.action(for: key),
              let def = Keymap.defaultAction(for: key) else { return false }
        return current != def && !current.isFnLayer
    }

    func setPending(_ action: KeyAction, for key: KeyDef) {
        if keysOnMac {
            setHostRemap(action, for: key)
            return
        }
        guard keymap?.canRemap(key) == true else {
            errorMessage = "Esta tecla tem uma função com Fn gravada no teclado. Trocar apagaria essa função, então o app não mexe nela."
            return
        }
        if keymap?.action(for: key) == action {
            pendingKeys[key.keymapSlot] = nil
        } else {
            pendingKeys[key.keymapSlot] = action
        }
    }

    func resetAllKeys() {
        if keysOnMac {
            hostRemaps.removeAll()
            saveState()
            applyHostRemaps(announce: true)
            return
        }
        guard let keymap else { return }
        for key in K652Layout.keys {
            guard let def = Keymap.defaultAction(for: key), keymap.action(for: key) != def,
                  !keymap.action(for: key).isFnLayer else { continue }
            pendingKeys[key.keymapSlot] = def
        }
    }

    // MARK: - Pelo cabo (matriz no teclado)

    func readKeymap() {
        hidQueue.async { [device] in
            let result = Result { try device.readKeymap() }
            DispatchQueue.main.async {
                switch result {
                case .success(let keymap): self.keymap = keymap
                case .failure(let error): self.errorMessage = "Não li a matriz de teclas: \(error.localizedDescription)"
                }
            }
        }
    }

    func applyKeys() {
        let changes = pendingKeys
        guard !changes.isEmpty else { return }
        runWrite("\(changes.count) tecla(s) gravada(s)") { device in
            try device.applyKeyChanges(changes)
        } done: {
            self.pendingKeys.removeAll()
            self.readKeymap()
        }
    }

    // MARK: - Pelo Bluetooth (remapeamento no Mac)

    private func setHostRemap(_ action: KeyAction, for key: KeyDef) {
        guard let usage = key.hidUsage else { return }
        guard HostKeyRemap.supports(action) else {
            errorMessage = "Pelo Bluetooth dá para trocar a tecla por outra tecla ou por mídia, sem atalho com modificador nem desativar."
            return
        }
        if action == Keymap.defaultAction(for: key) {
            hostRemaps[usage] = nil
        } else {
            hostRemaps[usage] = action
        }
        saveState()
        applyHostRemaps(announce: true)
    }

    func applyHostRemaps(announce: Bool) {
        let entries = HostKeyRemap.entries(hostRemaps)
        hidQueue.async {
            let result = Result { try HIDUtil.setUserKeyMapping(entries) }
            DispatchQueue.main.async {
                switch result {
                case .success:
                    guard announce else { return }
                    self.errorMessage = nil
                    self.message = entries.isEmpty ? "Teclas no padrão" : "\(entries.count) tecla(s) remapeada(s) no Mac"
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Descarta do estado salvo o que não é tecla do layout ou não cabe no hidutil.
    static func validHostRemaps(_ remaps: [UInt8: KeyAction]) -> [UInt8: KeyAction] {
        let usages = Set(K652Layout.keys.compactMap(\.hidUsage))
        return remaps.filter { usages.contains($0.key) && HostKeyRemap.supports($0.value) }
    }

    // MARK: - Abrir ao iniciar sessão

    /// Com o app aberto, o remapeamento volta sozinho quando o teclado reconecta.
    var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = "Não consegui mudar a abertura ao iniciar sessão: \(error.localizedDescription)"
        }
        objectWillChange.send()
    }
}
