import Foundation

/// Enough distinct 50 ms target slots must be heard before presenting an estimate.
/// This cannot distinguish the singer from a loudspeaker playing the same melody.
public enum RoomScoreReliability {
    public static func reportable(_ score: KaraokeScoreBreakdown?) -> KaraokeScoreBreakdown? {
        guard let score, score.matchedObservationCount >= 20,
              score.timingCoverage >= 10,
              score.overall.isFinite else { return nil }
        return score
    }
}
