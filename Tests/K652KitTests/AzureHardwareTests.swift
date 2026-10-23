import Testing
@testable import K652Kit

@Test func shortFeatureReportKeepsItsOwnIDByte() {
    let response = AzureFixtures.lightingResponse

    let normalized = HIDTransport.normalizeFeature(response, id: K652Report.data)

    #expect(normalized == response)
    #expect(normalized[1] == K652Command.getLighting.rawValue)
}

@Test func featureReportWithoutIDGetsItBack() {
    let stripped = Array(AzureFixtures.lightingResponse.dropFirst())

    let normalized = HIDTransport.normalizeFeature(stripped, id: K652Report.data)

    #expect(normalized == AzureFixtures.lightingResponse)
}

@Test func realAzureLightingBlockHasSignatureAndCurrentMode() throws {
    let block = LightingBlock(bytes: Array(AzureFixtures.lightingPayload.prefix(LightingBlock.size)))

    let current = try #require(block.settings(for: 3))
    let fixed = try #require(block.settings(for: 1))

    #expect(block.hasSignature)
    #expect(block.modeHW == 3)
    #expect(block.customGroup == 0)
    #expect(current.random && current.speed == 1 && current.brightness == 3)
    #expect(fixed.colorIndex == 5 && fixed.speed == 4 && fixed.brightness == 4)
}

@Test func realAzureKeymapFollowsTheLedOrder() {
    let keymap = Keymap(bytes: AzureFixtures.keymapPayload)
    let a = K652Layout.key(windowsVK: 0x41)!
    let f1 = K652Layout.key(windowsVK: 0x70)!
    let grave = K652Layout.key(windowsVK: 0xC0)!

    let matching = keymap.matchingKeyCount()

    #expect(matching == K652Layout.keys.filter { $0.hidUsage != nil }.count)
    #expect(keymap.looksLikeK652Keymap)
    #expect(keymap.action(for: a) == .key(usage: 0x04, modifiers: []))
    #expect(keymap.action(for: grave) == .key(usage: 0x35, modifiers: []))
    #expect(keymap.action(for: f1).isFnLayer)
}

@Test func keysWithAnFnFunctionCannotBeRemappedOverTheCable() {
    let keymap = Keymap(bytes: AzureFixtures.keymapPayload)
    let f1 = K652Layout.key(windowsVK: 0x70)!
    let a = K652Layout.key(windowsVK: 0x41)!

    #expect(!keymap.canRemap(f1))
    #expect(keymap.canRemap(a))
}

@Test func keymapInTheWrongOrderIsRejected() {
    var shuffled = AzureFixtures.keymapPayload
    let entries = Keymap.entryCount * KeyAction.size
    shuffled.replaceSubrange(0..<entries, with: Array(shuffled[4..<entries]) + Array(shuffled[0..<4]))

    let keymap = Keymap(bytes: shuffled)

    #expect(!keymap.looksLikeK652Keymap)
}
