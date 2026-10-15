import Foundation

public struct PlaybackTimeline: Equatable, Sendable {
    public var anchorMilliseconds: Int64
    public var durationMilliseconds: Int64?
    public var rate: Double

    public init(
        anchorMilliseconds: Int64 = 0,
        durationMilliseconds: Int64? = nil,
        rate: Double = 1.0
    ) {
        self.anchorMilliseconds = max(0, anchorMilliseconds)
        self.durationMilliseconds = durationMilliseconds.map { max(0, $0) }
        self.rate = rate.isFinite ? max(0, rate) : 1
    }

    public func position(afterElapsedMilliseconds elapsed: Int64) -> Int64 {
        let safeElapsed = max(0, elapsed)
        let safeRate = rate.isFinite ? max(0, rate) : 1
        let scaled = (Double(safeElapsed) * safeRate).rounded(.towardZero)
        let advanced = scaled >= Double(Int64.max) ? Int64.max : Int64(scaled)
        let unclamped = anchorMilliseconds.addingReportingOverflow(advanced)
        let value = unclamped.overflow ? Int64.max : unclamped.partialValue

        if let durationMilliseconds {
            return min(max(0, value), max(0, durationMilliseconds))
        }
        return max(0, value)
    }
}


