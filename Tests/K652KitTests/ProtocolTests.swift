import Testing
@testable import K652Kit

/// Bloco de iluminação como o teclado devolveria: assinatura no lugar e bytes desconhecidos preenchidos.
func sampleLightingBlock() -> LightingBlock {
    var bytes = [UInt8](repeating: 0x11, count: LightingBlock.size)
    bytes[LightingBlock.signatureOffset] = 0x5A
    bytes[LightingBlock.signatureOffset + 1] = 0xA5
    bytes[LightingBlock.modeOffset] = 3
    bytes[LightingBlock.groupOffset] = 0x22
    return LightingBlock(bytes: bytes)
}

@Test func writeBlockPutsHeaderAndPayloadWhereTheDriverDoes() throws {
    let report = try K652Protocol.blockReport(.setKeymap, address: 0xD4, marker: 0x40, payload: [0xAA, 0xBB])

    #expect(report.count == 0x408)
    #expect(Array(report[0..<8]) == [0x06, 0x04, 0xD4, 0x00, 0x40, 0x00, 0x00, 0x00])
    #expect(report[8] == 0xAA && report[9] == 0xBB)
}

@Test func writeBlockRejectsPayloadLargerThanTheReport() {
    #expect(throws: K652Error.self) {
        try K652Protocol.blockReport(.setKeymap, address: 0xD4, marker: 0x40, payload: [UInt8](repeating: 0, count: 0x401))
    }
}

@Test func lightingBlockReadsModeGroupAndPerModeSettings() {
    var block = sampleLightingBlock()
    let i = LightingBlock.perModeOffset + 2 * (2 - 1)
    block.bytes[i] = 0x83          // direção invertida, slot 3
    block.bytes[i + 1] = 0x42      // velocidade 4, brilho 2

    let s = block.settings(for: 2)

    #expect(block.modeHW == 3)
    #expect(block.customGroup == 2)
    #expect(block.hasSignature)
    #expect(s?.speed == 4 && s?.brightness == 2 && s?.colorIndex == 3)
    #expect(s?.reversed == true && s?.random == false)
}

@Test func lightingBlockTreatsColorIndexSevenAsRandom() {
    var block = sampleLightingBlock()
    block.bytes[LightingBlock.perModeOffset] = 0x07

    #expect(block.settings(for: 1)?.random == true)
}

@Test func applyWritesModeFlagsAndSignatureAndKeepsUnknownBytes() {
    var block = sampleLightingBlock()
    let custom = LightingMode.mode(hw: 21)!

    block.apply(mode: custom, group: 4, settings: [:])

    #expect(block.bytes[0] == 0)
    #expect(block.bytes[LightingBlock.customFlagOffset] == 1)
    #expect(block.bytes[LightingBlock.modeOffset] == 21)
    #expect(block.bytes[LightingBlock.groupOffset] == 0x24)
    #expect(block.bytes[28] == 0xFF && block.bytes[29] == 0xFF)
    #expect(block.hasSignature)
    #expect(block.bytes[5] == 0x11 && block.bytes[100] == 0x11)
}

@Test func applyOnlyTouchesTheFieldsEachModeSupports() {
    var block = sampleLightingBlock()
    let breathing = LightingMode.mode(hw: 2)!
    let rainbow = LightingMode.mode(hw: 3)!
    let settings: [UInt8: ModeSettings] = [
        2: ModeSettings(speed: 1, brightness: 3, colorIndex: 5),
        3: ModeSettings(speed: 0, brightness: 4, colorIndex: 6),
    ]

    block.apply(mode: breathing, group: 0, settings: settings)

    let b = LightingBlock.perModeOffset + 2 * (2 - 1)
    #expect(block.bytes[b] == 0x15)           // nibble alto preservado (0x1), slot 5
    #expect(block.bytes[b + 1] == 0x13)       // velocidade 1, brilho 3
    let r = LightingBlock.perModeOffset + 2 * (3 - 1)
    #expect(block.bytes[r] == 0x11)           // arco-íris não tem cor: byte intacto
    #expect(block.bytes[r + 1] == 0x04)       // velocidade 0, brilho 4
}

@Test func applyWritesRandomAsColorIndexSeven() {
    var block = sampleLightingBlock()
    var s = ModeSettings(colorIndex: 2)
    s.random = true

    block.apply(mode: LightingMode.mode(hw: 1)!, group: 0, settings: [1: s])

    #expect(block.bytes[LightingBlock.perModeOffset] & 0x0F == 7)
}

@Test func paletteTableLeavesModeZeroBlankAndIndexesByHardwareMode() {
    var breathing = ModeSettings()
    breathing.palette[0] = LEDColor(1, 2, 3)

    let table = PaletteTable.encode([2: breathing])

    #expect(table.count == 21 + 22 * 21)
    #expect(table[0..<21].allSatisfy { $0 == 0 })
    #expect(Array(table[21 * 2..<21 * 2 + 3]) == [1, 2, 3])
}

@Test func customColorMatrixFillsTwoChunksOf1024Bytes() {
    let groups = CustomColorMatrix.defaultGroups()

    let data = CustomColorMatrix.encode(groups: groups)
    let chunks = CustomColorMatrix.chunks(data)

    #expect(data.count == 1890)
    #expect(chunks.count == 2 && chunks.allSatisfy { $0.count == 1024 })
}

@Test func defaultCustomGroupsLightWASDInTheFirstGroup() {
    let groups = CustomColorMatrix.defaultGroups()
    let w = K652Layout.key(windowsVK: 0x57)!
    let q = K652Layout.key(windowsVK: 0x51)!

    #expect(groups.count == 5)
    #expect(groups[0][w.ledIndex] == .blue)
    #expect(groups[0][q.ledIndex] == .black)
}

@Test func directFrameMatchesTheMusicReport() {
    let frame = DirectFrame.encode([LEDColor(1, 2, 3)])

    #expect(frame.count == 0x17E)
    #expect(Array(frame[0..<7]) == [0x08, 0x0A, 0x7A, 0x01, 1, 2, 3])
}

@Test func keyActionRoundTripsEveryKnownEncoding() {
    let cases: [KeyAction] = [
        .key(usage: 0x04, modifiers: []),
        .key(usage: 0x06, modifiers: [.leftControl]),
        .key(usage: 0xE0, modifiers: []),
        .media(usage: 0x00CD),
        .media(usage: 0x0192),
        .disabled,
    ]
    for action in cases {
        #expect(KeyAction(bytes: action.bytes) == action)
    }
    #expect(KeyAction.media(usage: 0x0183).bytes == [0x04, 0x00, 0x01, 0x83])
    #expect(KeyAction.key(usage: 0x06, modifiers: [.leftControl]).bytes == [0x00, 0x00, 0x01, 0x06])
}

@Test func keyActionKeepsUnknownEntriesUntouched() {
    let raw: [UInt8] = [0x02, 0x00, 0x00, 0x03]

    let action = KeyAction(bytes: raw)

    #expect(action.isFnLayer)
    #expect(action.bytes == raw)
}

@Test func layoutHasEightyFourKeysWithUniqueLedsAndMatrixSlots() {
    let keys = K652Layout.keys

    #expect(keys.count == 84)
    #expect(Set(keys.map(\.ledIndex)).count == 84)
    #expect(Set(keys.map(\.keymapSlot)).count == 84)
    #expect(keys.allSatisfy { $0.ledIndex < K652Layout.ledCount && $0.keymapSlot < Keymap.entryCount })
    #expect(keys.filter { $0.hidUsage == nil }.map(\.label) == ["Fn"])
}

@Test func keymapCountsRecognizedKeys() {
    var bytes = [UInt8](repeating: 0xEE, count: 0x400)
    for key in K652Layout.keys {
        let action = Keymap.defaultAction(for: key) ?? .disabled
        for (i, b) in action.bytes.enumerated() { bytes[key.keymapSlot * 4 + i] = b }
    }

    let keymap = Keymap(bytes: bytes)

    #expect(keymap.matchingKeyCount() == 83)
    #expect(keymap.action(for: K652Layout.key(windowsVK: 0x41)!) == .key(usage: 0x04, modifiers: []))
}

@Test func sanitizedSettingsClampLevelsAndRepairThePalette() {
    let broken = ModeSettings(speed: 9, brightness: -3, colorIndex: 12, palette: [LEDColor(1, 2, 3)])

    let fixed = broken.sanitized()

    #expect(fixed.speed == 4)
    #expect(fixed.brightness == 0)
    #expect(fixed.colorIndex == 0)
    #expect(fixed.palette.count == ModeSettings.paletteSize)
    #expect(fixed.palette[0] == LEDColor(1, 2, 3))
    #expect(fixed.palette[1] == ModeSettings.defaultPalette[1])
}
