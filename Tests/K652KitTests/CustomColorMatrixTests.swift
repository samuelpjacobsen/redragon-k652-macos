import Testing
@testable import K652Kit

/// Cores salvas (0x09) caíam em teclas trocadas: o app indexava o plano pelo LED, e o driver indexa
/// pelo último campo do [KEY] do Cfg.ini (FUN_0040d3b0 lê `DAT_005dcdcc`, que FUN_0043eed0 preenche
/// com o campo 8). Na linha "K15=..., 0x02,0xC0,0x00,1,21" a tecla ` tem LED 1 e posição 21.
@Test func savedColorFollowsTheDriverKeyOrderNotTheLED() {
    let grave = K652Layout.key(windowsVK: 0xC0)!
    var groups = [[LEDColor]](repeating: [LEDColor](repeating: .black, count: 126), count: 5)
    groups[0][grave.ledIndex] = LEDColor(0xFF, 0, 0)

    let data = CustomColorMatrix.encode(groups: groups)

    #expect(data[21] == 0xFF)
    #expect(data[1] == 0)
}

@Test func savedColorUsesThePlanesOfItsGroup() {
    let q = K652Layout.key(windowsVK: 0x51)!
    var groups = [[LEDColor]](repeating: [LEDColor](repeating: .black, count: 126), count: 5)
    groups[1][q.ledIndex] = LEDColor(9, 8, 7)

    let data = CustomColorMatrix.encode(groups: groups)

    // Q: "K31=..., 0x02,0x51,0x00,8,43"
    #expect(data[3 * 126 + 43] == 9)
    #expect(data[4 * 126 + 43] == 8)
    #expect(data[5 * 126 + 43] == 7)
    #expect(data[3 * 126 + q.ledIndex] == 0)
}

@Test func everyKeyHasItsOwnPositionInsideAPlane() {
    let positions = K652Layout.keys.map(\.customColorSlot)

    #expect(Set(positions).count == K652Layout.keys.count)
    #expect(positions.allSatisfy { (0..<CustomColorMatrix.planeSize).contains($0) })
}

@Test func fillingAGroupPaintsEveryKeyAndKeepsTheOthers() {
    let base = CustomColorMatrix.defaultGroups()
    let white = LEDColor.white

    let groups = CustomColorMatrix.filling(group: 4, with: white, base: base)
    let data = CustomColorMatrix.encode(groups: groups)

    #expect(groups[4].allSatisfy { $0 == white })
    #expect(Array(groups[0..<4]) == Array(base[0..<4]))
    for key in K652Layout.keys {
        #expect(data[(3 * 4 + 1) * CustomColorMatrix.planeSize + key.customColorSlot] == 0xFF)
    }
}

@Test func fillingAGroupOutOfRangeChangesNothing() {
    let base = CustomColorMatrix.defaultGroups()

    let groups = CustomColorMatrix.filling(group: 5, with: .white, base: base)

    #expect(groups == base)
}
