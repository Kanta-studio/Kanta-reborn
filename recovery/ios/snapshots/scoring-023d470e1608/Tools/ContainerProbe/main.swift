import Foundation
import LegacyCompatibility

struct ContainerProbeOutput: Codable {
    let index: IndexedLibraryProbeResult
    let recognizedContainerPayload: Bool?
}

let arguments = CommandLine.arguments

guard (2...3).contains(arguments.count) else {
    FileHandle.standardError.write(
        Data(
            (
                "usage: kanta-container-probe " +
                "<index-path> [container-path]\n"
            ).utf8
        )
    )
    exit(64)
}

let indexURL = URL(fileURLWithPath: arguments[1])
let indexData = try Data(
    contentsOf: indexURL,
    options: [.mappedIfSafe]
)

let containerURL =
    arguments.count == 3
    ? URL(fileURLWithPath: arguments[2])
    : nil

let containerByteCount: Int?
if let containerURL {
    let attributes = try FileManager.default.attributesOfItem(
        atPath: containerURL.path
    )
    guard let fileSize = attributes[.size] as? NSNumber else {
        FileHandle.standardError.write(
            Data(
                "error: unable to determine media-container size\n".utf8
            )
        )
        exit(65)
    }
    containerByteCount = fileSize.intValue
} else {
    containerByteCount = nil
}

let indexReport = IndexedLibraryProbe.inspect(
    indexData,
    containerByteCount: containerByteCount
)

let recognizedContainerPayload =
    containerURL.map {
        ContainerPayloadProbe.containsRecognizedPayload(
            indexData: indexData,
            containerURL: $0,
            sampleLimit: 32
        )
    }

let report = ContainerProbeOutput(
    index: indexReport,
    recognizedContainerPayload: recognizedContainerPayload
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
FileHandle.standardOutput.write(try encoder.encode(report))
FileHandle.standardOutput.write(Data("\n".utf8))

