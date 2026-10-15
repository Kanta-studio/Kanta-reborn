import Foundation
import Testing
@testable import LegacyCompatibility

@Test func probeParsesTitleIndexAndTrailingRelationship() {
    var data = Data(repeating: 0, count: 28)
    data.replaceSubrange(20..<24, with: [28, 0, 0, 0])

    data.append(contentsOf: [0x06, 0x08, 0x00, 0x00])
    data.append(contentsOf: Array("Male".utf8))

    data.append(contentsOf: [0x01, 0x11, 0x01, 0x00, 1, 0, 0, 0, 2, 0, 0, 0])
    data.append(contentsOf: Array("Dream".utf8))

    data.append(contentsOf: [0x09, 0x00, 0x01, 0x02])

    let report = ShubIndexProbe.inspect(data)

    #expect(report.metadataRecordCount == 1)
    #expect(report.titleIndexRecordCount == 1)
    #expect(report.titleIndexSamples.first?.title == "Dream")
    #expect(report.titleIndexSamples.first?.opaqueA == 1)
    #expect(report.titleIndexSamples.first?.opaqueB == 2)
    #expect(report.trailingByteCount == 4)
    #expect(report.trailingBytesPerTitleRecord == 4)
}

