import Foundation
import Testing
@testable import K652Kit

@Test func hostRemapEncodesKeyAndMediaWithTheirUsagePages() {
    let remaps: [UInt8: KeyAction] = [0x3A: .media(usage: 0x00CD), 0x39: .key(usage: 0xE0, modifiers: [])]

    let entries = HostKeyRemap.entries(remaps)

    #expect(entries == [
        HostKeyRemap.Entry(source: 0x7_0000_0039, destination: 0x7_0000_00E0),
        HostKeyRemap.Entry(source: 0x7_0000_003A, destination: 0xC_0000_00CD),
    ])
}

@Test func hostRemapSkipsWhatHidutilCannotDo() {
    let remaps: [UInt8: KeyAction] = [
        0x04: .key(usage: 0x06, modifiers: .leftGUI),
        0x05: .disabled,
        0x06: .other([1, 2, 3, 4]),
        0x07: .key(usage: 0x07, modifiers: []),
    ]

    let entries = HostKeyRemap.entries(remaps)

    #expect(entries.isEmpty)
    #expect(!HostKeyRemap.supports(.disabled))
    #expect(!HostKeyRemap.supports(.key(usage: 0x06, modifiers: .leftControl)))
    #expect(HostKeyRemap.supports(.media(usage: 0x00E9)))
}

@Test func hostRemapPropertyIsPlainJSONForHidutil() throws {
    let entries = [HostKeyRemap.Entry(source: 0x7_0000_0039, destination: 0x7_0000_00E0)]

    let json = HostKeyRemap.propertyJSON(entries)

    let parsed = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: [[String: Int]]])
    #expect(parsed["UserKeyMapping"] == [[
        "HIDKeyboardModifierMappingSrc": 0x7_0000_0039,
        "HIDKeyboardModifierMappingDst": 0x7_0000_00E0,
    ]])
    #expect(HostKeyRemap.propertyJSON([]) == #"{"UserKeyMapping":[]}"#)
}

@Test func bluetoothMatchingTargetsOnlyTheK652Module() throws {
    let json = BluetoothKeyboard.matchingJSON

    let parsed = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Int])
    #expect(parsed == ["VendorID": 0x000E, "ProductID": 0x3412])
}
