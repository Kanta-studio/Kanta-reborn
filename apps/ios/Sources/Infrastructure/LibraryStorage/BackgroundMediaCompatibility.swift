import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

public enum BackgroundMediaCompatibilityKind:
    String,
    Codable,
    Hashable,
    Sendable
{
    case video
    case image
}

public struct BackgroundMediaCompatibilityReport:
    Equatable,
    Sendable
{
    public let kind: BackgroundMediaCompatibilityKind?
    public let isCompatible: Bool
    public let summary: String
    public let detail: String

    public init(
        kind: BackgroundMediaCompatibilityKind?,
        isCompatible: Bool,
        summary: String,
        detail: String
    ) {
        self.kind = kind
        self.isCompatible = isCompatible
        self.summary = summary
        self.detail = detail
    }
}

public struct BackgroundMediaCompatibilityInspector:
    Sendable
{
    public init() {}

    public func inspect(
        _ url: URL
    ) async -> BackgroundMediaCompatibilityReport {
        switch DirectoryLibraryScanner.classify(url) {
        case .backgroundVideo:
            return await inspectVideo(url)

        case .backgroundImage:
            return inspectImage(url)

        default:
            return BackgroundMediaCompatibilityReport(
                kind: nil,
                isCompatible: false,
                summary: "Unsupported file type",
                detail:
                    "Choose MP4, MOV, or M4V video, or JPG, JPEG, " +
                    "PNG, HEIC, or WebP image."
            )
        }
    }

    private func inspectVideo(
        _ url: URL
    ) async -> BackgroundMediaCompatibilityReport {
        let asset = AVURLAsset(url: url)

        do {
            let isPlayable = try await asset.load(.isPlayable)
            guard isPlayable else {
                return incompatibleVideo(
                    "iOS reported that this video is not playable."
                )
            }

            let tracks = try await asset.loadTracks(
                withMediaType: .video
            )
            guard let track = tracks.first else {
                return incompatibleVideo(
                    "No decodable video track was found."
                )
            }

            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let transformed = naturalSize.applying(transform)
            let width = Int(abs(transformed.width).rounded())
            let height = Int(abs(transformed.height).rounded())
            let duration = try await asset.load(.duration)
            let seconds = duration.seconds

            guard width > 0, height > 0 else {
                return incompatibleVideo(
                    "The video does not expose a valid display size."
                )
            }

            var facts = ["\(width)×\(height)"]
            if seconds.isFinite, seconds >= 0 {
                facts.append(Self.durationText(seconds))
            }

            return BackgroundMediaCompatibilityReport(
                kind: .video,
                isCompatible: true,
                summary: "Compatible video",
                detail:
                    facts.joined(separator: " • ") +
                    " • playable by iOS. The original file will be " +
                    "copied without re-encoding or recompression."
            )
        } catch {
            return incompatibleVideo(
                "iOS could not decode this video: " +
                error.localizedDescription
            )
        }
    }

    private func inspectImage(
        _ url: URL
    ) -> BackgroundMediaCompatibilityReport {
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            nil
        ),
        CGImageSourceGetCount(source) > 0 else {
            return BackgroundMediaCompatibilityReport(
                kind: .image,
                isCompatible: false,
                summary: "Unsupported image",
                detail:
                    "iOS could not decode this image. Export it as " +
                    "JPG, PNG, HEIC, or WebP and try again."
            )
        }

        let properties =
            CGImageSourceCopyPropertiesAtIndex(
                source,
                0,
                nil
            ) as? [CFString: Any]

        let width = (properties?[
            kCGImagePropertyPixelWidth
        ] as? NSNumber)?.intValue ?? 0
        let height = (properties?[
            kCGImagePropertyPixelHeight
        ] as? NSNumber)?.intValue ?? 0

        guard width > 0, height > 0 else {
            return BackgroundMediaCompatibilityReport(
                kind: .image,
                isCompatible: false,
                summary: "Unsupported image",
                detail:
                    "The image decoded, but its pixel dimensions " +
                    "could not be validated."
            )
        }

        return BackgroundMediaCompatibilityReport(
            kind: .image,
            isCompatible: true,
            summary: "Compatible image",
            detail:
                "\(width)×\(height) • readable by iOS. The original " +
                "file will be copied without resizing or recompression."
        )
    }

    private func incompatibleVideo(
        _ detail: String
    ) -> BackgroundMediaCompatibilityReport {
        BackgroundMediaCompatibilityReport(
            kind: .video,
            isCompatible: false,
            summary: "Unsupported video",
            detail: detail
        )
    }

    private static func durationText(
        _ seconds: Double
    ) -> String {
        let total = max(0, Int(seconds.rounded()))
        let minutes = total / 60
        let remainder = total % 60
        return String(
            format: "%d:%02d",
            minutes,
            remainder
        )
    }
}

