import Foundation

public struct PairingCode:
    Hashable,
    Codable,
    Sendable,
    CustomStringConvertible
{
    public static let digitCount = 6

    public let value: String

    public init?(_ value: String) {
        guard value.count == Self.digitCount,
              value.allSatisfy(\.isNumber) else {
            return nil
        }
        self.value = value
    }

    public init?(number: Int) {
        guard (0...999_999).contains(number) else {
            return nil
        }
        self.init(String(format: "%06d", number))
    }

    public static func generate() -> PairingCode {
        PairingCode(
            number: Int.random(in: 0...999_999)
        )!
    }

    public var description: String { value }
}

