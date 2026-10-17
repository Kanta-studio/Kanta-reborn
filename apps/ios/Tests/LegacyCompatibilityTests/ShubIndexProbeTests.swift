import Foundation
import Testing
@testable import LegacyCompatibility

@Test func probeFollowsObservedMetadataRecordLayouts() {
    var data = Data(repeating: 0, count: 28)
    data.replaceSubrange(20..<24, with: [28, 0, 0, 0])

    data.append(contentsOf: [0x06, 0x08, 0x00, 0x00])
    data.append(contentsOf: Array("Male".utf8))

    data.append(contentsOf: [0x04, 0x09, 0x02, 0x00, 0x00])
    data.append(contentsOf: Array("Rock".utf8))

    data.append(contentsOf: [0x01, 0x04, 0x00, 0x00])

    let report = ShubIndexProbe.inspect(data)
    #expect(report.metadataTableOffset == 28)
    #expect(report.metadataRecordCount == 2)
    #expect(report.metadataRecordCountsByKind[6] == 1)
    #expect(report.metadataRecordCountsByKind[4] == 1)
    #expect(report.metadataSamples.map(\.text) == ["Male", "Rock"])
    #expect(report.firstUnparsedKind == 1)
}

