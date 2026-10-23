import Foundation
import K652Kit

func hexDump(_ bytes: [UInt8], width: Int = 16) -> String {
    stride(from: 0, to: bytes.count, by: width).map { start in
        String(format: "%04X  ", start) + Array(bytes[start..<min(start + width, bytes.count)]).hexString
    }.joined(separator: "\n")
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("erro: \(message)\n".utf8))
    exit(1)
}

func usage() -> Never {
    print("""
    uso: k652ctl <comando>
      info                         interfaces HID, firmware, identificação e modo atual
      dump-light                   bloco de iluminação (0x83) em hex
      dump-keys                    matriz de teclas (0x84) em hex e decodificada
      dump <cmd> <end>             leitura crua (cmd 81...8F em hex), sem gravar nada
      mode <hw> [brilho] [veloc] [slot]
                                   troca o modo (0 desligado, 1 fixo... 21 personalizado);
                                   slot 0...6 escolhe a cor da paleta padrão (1 = azul)
      color <hw> RRGGBB            cor fixa no slot 0 da paleta do modo
      fill RRGGBB [grupo]          todas as teclas numa cor, no modo Personalizado (grupo 1...5)
      live RRGGBB [segundos]       pinta tudo ao vivo pelo report 8 (não grava)
      --force                      grava mesmo sem confirmar o modelo
    """)
    exit(2)
}

func parseColor(_ text: String) -> LEDColor? {
    guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
    return LEDColor(UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF))
}

var args = Array(CommandLine.arguments.dropFirst())
let force = args.contains("--force")
args.removeAll { $0 == "--force" }
guard let command = args.first else { usage() }

let device = K652Device()
let snapshot: DeviceSnapshot
do {
    snapshot = try device.connect()
} catch K652Error.notFound where K652Monitor().bluetoothPresent {
    fail("o K652 está ligado só pelo Bluetooth, que não aceita comandos de configuração. Ligue o cabo USB.")
} catch {
    fail(error.localizedDescription)
}

/// Espera antes de reler o que foi gravado. O Azure pode sumir do USB cerca de 1 s depois de aplicar
/// (log do kernel, 23/10/2026); a espera garante que a releitura passe pela reconexão.
let readbackDelay: TimeInterval = 2
/// Comandos de leitura: o bit alto ligado (0x83 lê o que 0x03 grava, 0x84 o que 0x04 grava).
let readOnlyCommands: ClosedRange<UInt8> = 0x81...0x8F

func printReadback() {
    Thread.sleep(forTimeInterval: readbackDelay)
    do {
        let block = try device.readLighting()
        let name = LightingMode.mode(hw: block.modeHW)?.name ?? "desconhecido"
        let detail = block.settings(for: block.modeHW).map {
            "brilho \($0.brightness), velocidade \($0.speed), cor \($0.random ? "aleatória" : "slot \($0.colorIndex)")"
        } ?? ""
        let group = LightingMode.mode(hw: block.modeHW)?.isCustom == true ? "grupo \(block.customGroup + 1)" : ""
        print("Gravado e relido: modo \(block.modeHW) (\(name)) \(detail)\(group)")
    } catch {
        fail("gravei, mas não consegui reler: \(error.localizedDescription)")
    }
}

func requireWritable() {
    if !snapshot.looksLikeK652 && !force {
        fail("o teclado não foi confirmado como K652 (\(snapshot.identity.summary)). Use --force por sua conta.")
    }
}

func settingsFromKeyboard() -> [UInt8: ModeSettings] {
    var settings: [UInt8: ModeSettings] = [:]
    for mode in LightingMode.all {
        settings[mode.hw] = snapshot.lighting?.settings(for: mode.hw) ?? ModeSettings()
    }
    return settings
}

do {
    switch command {
    case "info":
        print("Produto: \(snapshot.productName)")
        print(String(format: "Firmware: 0x%04X", snapshot.firmwareVersion))
        snapshot.interfaces.forEach { print("Interface: \($0)") }
        print("Identificação: \(snapshot.identity.summary)")
        print("Pré-visualização ao vivo (report 8): \(snapshot.supportsLivePreview ? "sim" : "não")")
        if let block = snapshot.lighting {
            let name = LightingMode.mode(hw: block.modeHW)?.name ?? "desconhecido"
            print("Modo atual: \(block.modeHW) (\(name)), grupo \(block.customGroup + 1), assinatura \(block.hasSignature ? "ok" : "ausente")")
            if let s = block.settings(for: block.modeHW) {
                print("  brilho \(s.brightness), velocidade \(s.speed), cor \(s.random ? "aleatória" : "slot \(s.colorIndex)")")
            }
        } else {
            print("Iluminação: \(snapshot.lightingError ?? "sem leitura")")
        }
    case "dump-light":
        print(hexDump(try device.readLighting().bytes))
    case "dump-keys":
        let keymap = try device.readKeymap()
        print(hexDump(keymap.bytes))
        print("Teclas no lugar (padrão ou Fn): \(keymap.matchingKeyCount())/\(K652Layout.keys.count)")
        for key in K652Layout.keys {
            print("  \(key.label.padding(toLength: 7, withPad: " ", startingAt: 0)) [\(key.keymapSlot)] = \(keymap.action(for: key).displayName)")
        }
    case "dump":
        guard args.count >= 3, let cmd = UInt8(args[1], radix: 16), let address = UInt8(args[2], radix: 16),
              readOnlyCommands.contains(cmd) else { usage() }
        try device.transport.setFeature([K652Report.command, cmd, address, 0, 0, 0])
        Thread.sleep(forTimeInterval: HIDTransport.responseDelay)
        print(hexDump(try device.transport.getFeature(K652Report.data)))
    case "mode":
        guard args.count >= 2, let hw = UInt8(args[1]), let mode = LightingMode.mode(hw: hw) else { usage() }
        requireWritable()
        var settings = settingsFromKeyboard()
        if args.count >= 3, let b = Int(args[2]) { settings[hw]?.brightness = b }
        if args.count >= 4, let s = Int(args[3]) { settings[hw]?.speed = s }
        if args.count >= 5, let slot = Int(args[4]), (0..<ModeSettings.paletteSize).contains(slot) {
            settings[hw]?.colorIndex = slot
            settings[hw]?.random = false
        }
        try device.applyLighting(mode: mode, group: snapshot.lighting?.customGroup ?? 0,
                                 settings: settings, customGroups: nil)
        printReadback()
    case "color":
        guard args.count >= 3, let hw = UInt8(args[1]), let mode = LightingMode.mode(hw: hw),
              let color = parseColor(args[2]) else { usage() }
        requireWritable()
        var settings = settingsFromKeyboard()
        settings[hw]?.palette[0] = color
        settings[hw]?.colorIndex = 0
        settings[hw]?.random = false
        try device.applyLighting(mode: mode, group: snapshot.lighting?.customGroup ?? 0, settings: settings, customGroups: nil)
        printReadback()
    case "fill":
        guard args.count >= 2, let color = parseColor(args[1]) else { usage() }
        let group = args.count >= 3 ? (Int(args[2]) ?? 0) - 1 : snapshot.lighting?.customGroup ?? 0
        guard (0..<LightingBlock.groupCount).contains(group) else { usage() }
        requireWritable()
        // As cores por tecla não são legíveis: os outros grupos voltam ao padrão do driver.
        let groups = CustomColorMatrix.filling(group: group, with: color, base: CustomColorMatrix.defaultGroups())
        try device.applyLighting(mode: LightingMode.mode(hw: LightingMode.customHW)!, group: group,
                                 settings: settingsFromKeyboard(), customGroups: groups)
        printReadback()
    case "live":
        guard args.count >= 2, let color = parseColor(args[1]) else { usage() }
        let seconds = args.count >= 3 ? Double(args[2]) ?? 3 : 3
        let frames = Int(seconds * 10)
        for _ in 0..<frames {
            try device.sendLiveFrame([LEDColor](repeating: color, count: K652Layout.ledCount))
            Thread.sleep(forTimeInterval: 0.1)
        }
        print("Enviados \(frames) quadros")
    default:
        usage()
    }
} catch {
    fail(error.localizedDescription)
}
