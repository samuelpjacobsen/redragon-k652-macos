import IOKit
import Testing
@testable import K652Kit

/// O Azure se desconecta e volta no USB depois de aplicar a iluminação (log do kernel em 23/10/2026:
/// "terminateDevice ... hardware connection lost" seguido de "enumerated 0x258a/0049").
/// A referência antiga passa a devolver MACH_SEND_INVALID_DEST (0x10000003).
let machSendInvalidDest = IOReturn(bitPattern: 0x1000_0003)

@Test func lostDeviceErrorsAreRecognized() {
    #expect(K652Error.setReportFailed(5, machSendInvalidDest).isLostDevice)
    #expect(K652Error.getReportFailed(6, IOReturn(bitPattern: 0xE000_02C0)).isLostDevice)
    #expect(!K652Error.setReportFailed(5, IOReturn(bitPattern: 0xE000_02BC)).isLostDevice)
    #expect(!K652Error.badResponse("x").isLostDevice)
}

@Test func lostDeviceIsReopenedAndTheOperationRepeated() throws {
    var attempts = 0
    var reopened = 0

    let value = try HIDTransport.recoveringFromReset({
        attempts += 1
        if attempts == 1 { throw K652Error.setReportFailed(5, machSendInvalidDest) }
        return 42
    }, reopen: { reopened += 1 })

    #expect(value == 42)
    #expect(attempts == 2)
    #expect(reopened == 1)
}

@Test func otherErrorsAreNotRetried() {
    var reopened = 0

    #expect(throws: K652Error.self) {
        try HIDTransport.recoveringFromReset({ () throws -> Int in
            throw K652Error.badResponse("esperava 0x83")
        }, reopen: { reopened += 1 })
    }
    #expect(reopened == 0)
}
