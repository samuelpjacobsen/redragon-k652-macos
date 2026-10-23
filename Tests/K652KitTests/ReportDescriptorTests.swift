import Testing
@testable import K652Kit

/// Descritor da interface de configuração do K652 Azure pelo cabo (258A:0049, "Gaming Keyboard", BY Tech),
/// lido em 23/10/2026. O macOS entrega o descritor mesmo sem a permissão de Monitoramento de Entrada.
let azureUSBDescriptor: [UInt8] = hex("""
06 01 00 09 80 A1 01 85 01 19 81 29 83 15 00 25 01 95 03 75 01 81 02 95 01 75 05 81 01 C0 05 0C 09 01 \
A1 01 85 02 19 00 2A FF 02 15 00 26 FF 7F 95 01 75 10 81 00 C0 06 00 FF 09 01 A1 01 85 03 15 00 26 FF \
00 09 2F 75 08 95 03 81 02 C0 05 01 09 06 A1 01 85 04 05 07 19 04 29 70 15 00 25 01 75 01 95 78 81 02 \
C0 06 00 FF 09 01 A1 01 85 05 15 00 26 FF 00 19 01 29 02 75 08 95 05 B1 02 C0 06 00 FF 09 01 A1 01 85 \
06 15 00 26 FF 00 19 01 29 02 75 08 96 07 04 B1 02 C0 05 01 09 02 A1 01 85 07 09 01 A1 00 05 09 15 00 \
25 01 19 01 29 05 75 01 95 05 81 02 95 03 81 01 05 01 16 00 80 26 FF 7F 09 30 09 31 75 10 95 02 81 06 \
15 81 25 7F 09 38 75 08 95 01 81 06 05 0C 0A 38 02 95 01 81 06 C0 C0 06 00 FF 09 01 A1 01 85 08 15 00 \
26 FF 00 09 00 75 08 96 7D 01 B1 02 C0
""")

func hex(_ text: String) -> [UInt8] {
    text.split(whereSeparator: { $0 == " " || $0 == "\n" }).compactMap { UInt8($0, radix: 16) }
}

@Test func descriptorGivesTheAzureFeatureReportsWithTheirIDByte() {
    let sizes = ReportDescriptor.featureReportSizes(azureUSBDescriptor)

    #expect(sizes == [5: 6, 6: 0x408, 8: 0x17E])
}

@Test func descriptorOfThePlainKeyboardInterfaceHasNoFeatureReports() {
    let keyboardOnly = hex("""
    05 01 09 06 A1 01 05 07 19 E0 29 E7 15 00 25 01 95 08 75 01 81 02 95 01 75 08 81 03 95 06 75 08 15 00 \
    26 FF 00 05 07 19 00 2A FF 00 81 00 25 01 95 05 75 01 05 08 19 01 29 05 91 02 95 01 75 03 91 03 C0
    """)

    let sizes = ReportDescriptor.featureReportSizes(keyboardOnly)

    #expect(sizes.isEmpty)
}

@Test func descriptorParserSurvivesTruncatedInput() {
    let truncated = Array(azureUSBDescriptor.prefix(azureUSBDescriptor.count - 1)) + [0x96, 0x07]

    let sizes = ReportDescriptor.featureReportSizes(truncated)

    #expect(sizes[5] == 6)
}
