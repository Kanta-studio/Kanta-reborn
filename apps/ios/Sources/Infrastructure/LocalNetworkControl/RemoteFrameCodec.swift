import Foundation
import GeloKaraokeCore

public enum RemoteFrameCodecError: Error, Equatable, Sendable {
    case emptyFrame
    case frameTooLarge(Int)
    case unsupportedProtocolVersion(UInt16)
    case invalidEnvelope
}

public enum RemoteFrameCodec {
    public static let maximumPayloadByteCount = 1_048_576

    public static func encode(
        _ envelope: RemoteEnvelope
    ) throws -> Data {
        let encoder = JSONEncoder()
        let payload = try encoder.encode(envelope)

        guard !payload.isEmpty else {
            throw RemoteFrameCodecError.emptyFrame
        }
        guard payload.count <= maximumPayloadByteCount else {
            throw RemoteFrameCodecError.frameTooLarge(
                payload.count
            )
        }

        let length = UInt32(payload.count)
        var framed = Data(capacity: 4 + payload.count)
        framed.append(UInt8(truncatingIfNeeded: length >> 24))
        framed.append(UInt8(truncatingIfNeeded: length >> 16))
        framed.append(UInt8(truncatingIfNeeded: length >> 8))
        framed.append(UInt8(truncatingIfNeeded: length))
        framed.append(payload)
        return framed
    }
}

public struct RemoteFrameStreamDecoder: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func append(
        _ data: Data
    ) throws -> [RemoteEnvelope] {
        buffer.append(data)

        var envelopes: [RemoteEnvelope] = []

        while buffer.count >= 4 {
            let prefix = Array(buffer.prefix(4))
            let payloadLength =
                Int(UInt32(prefix[0]) << 24)
                | Int(UInt32(prefix[1]) << 16)
                | Int(UInt32(prefix[2]) << 8)
                | Int(UInt32(prefix[3]))

            guard payloadLength > 0 else {
                throw RemoteFrameCodecError.emptyFrame
            }
            guard payloadLength
                    <= RemoteFrameCodec.maximumPayloadByteCount else {
                throw RemoteFrameCodecError.frameTooLarge(
                    payloadLength
                )
            }

            let totalLength = 4 + payloadLength
            guard buffer.count >= totalLength else {
                return envelopes
            }

            let payload = Data(buffer[4..<totalLength])
            let envelope: RemoteEnvelope
            do {
                envelope = try JSONDecoder().decode(
                    RemoteEnvelope.self,
                    from: payload
                )
            } catch {
                throw RemoteFrameCodecError.invalidEnvelope
            }

            guard envelope.protocolVersion
                    == GeloRemoteProtocol.currentVersion else {
                throw RemoteFrameCodecError
                    .unsupportedProtocolVersion(
                        envelope.protocolVersion
                    )
            }

            envelopes.append(envelope)
            buffer.removeSubrange(0..<totalLength)
        }

        return envelopes
    }
}

