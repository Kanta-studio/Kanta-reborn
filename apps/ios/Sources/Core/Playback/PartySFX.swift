import Foundation

/// KANTA-authored, procedurally synthesized party sounds. No third-party
/// sound recording or proprietary sample is bundled with the app.
public enum PartySFX: String, Codable, CaseIterable, Identifiable, Sendable {
    case applause, cheering, drumRoll, airHorn, laughter, taDa, ding, sadTrombone

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .applause: "Applause"
        case .cheering: "Cheering"
        case .drumRoll: "Drum Roll"
        case .airHorn: "Air Horn"
        case .laughter: "Laughter"
        case .taDa: "Ta-Da!"
        case .ding: "Ding"
        case .sadTrombone: "Sad Trombone"
        }
    }
    public var symbol: String {
        switch self {
        case .applause: "hands.clap.fill"
        case .cheering: "party.popper.fill"
        case .drumRoll: "circle.grid.cross"
        case .airHorn: "megaphone.fill"
        case .laughter: "face.smiling"
        case .taDa: "sparkles"
        case .ding: "bell.fill"
        case .sadTrombone: "music.note"
        }
    }
}

public protocol PartySFXPlayback: Sendable {
    func trigger(_ sound: PartySFX) async throws
    func stopAll() async
    func setSFXVolume(_ value: Float) async
}

