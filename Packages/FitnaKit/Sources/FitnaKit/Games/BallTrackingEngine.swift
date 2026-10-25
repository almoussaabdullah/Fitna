import Foundation

/// تتبّع الكرة — follow the highlighted ball while balls swap places.
///
/// Balls sit in fixed slots arranged in a circle. A round is a deterministic list
/// of swaps between slot pairs; the engine tracks where the target ends up, so the
/// correct answer never depends on animation timing.
public struct BallTrackingEngine: GameEngine {
    public struct Swap: Equatable, Sendable {
        public let a: Int
        public let b: Int
    }

    public struct Round: Equatable, Sendable {
        public let ballCount: Int
        public let targetStartSlot: Int
        public let swaps: [Swap]
        public let swapDuration: Double

        /// Slot holding the target after all swaps.
        public var targetFinalSlot: Int {
            BallTrackingEngine.finalSlot(start: targetStartSlot, swaps: swaps)
        }
    }

    public let gameID = GameID.ballTracking
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var round: Round?
    public private(set) var roundsPlayed = 0
    private var rng: AnyRNG

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        self.level = Difficulty.clamp(level)
        self.length = length
        self.rng = rng
    }

    public var totalRounds: Int { length == .standard ? 6 : 4 }
    public var ballCount: Int { 3 + (level - 1) / 2 }
    public var swapCount: Int { 3 + level }
    public var swapDuration: Double { levelLerp(level, from: 0.75, to: 0.30) }
    public var isFinished: Bool { roundsPlayed >= totalRounds }

    public static func finalSlot(start: Int, swaps: [Swap]) -> Int {
        var slot = start
        for s in swaps {
            if slot == s.a { slot = s.b } else if slot == s.b { slot = s.a }
        }
        return slot
    }

    @discardableResult
    public mutating func startRound() -> Round {
        let n = ballCount
        let target = Int.random(in: 0..<n, using: &rng)
        var swaps: [Swap] = []
        var involvesTarget = 0
        var slot = target
        while swaps.count < swapCount {
            let a = Int.random(in: 0..<n, using: &rng)
            var b = Int.random(in: 0..<(n - 1), using: &rng)
            if b >= a { b += 1 }
            let swap = Swap(a: min(a, b), b: max(a, b))
            if let last = swaps.last, last == swap { continue } // an immediate undo looks like nothing happened
            swaps.append(swap)
            if slot == swap.a || slot == swap.b {
                involvesTarget += 1
                slot = slot == swap.a ? swap.b : swap.a
            }
        }
        // Guarantee the target itself moves several times.
        let required = min(swapCount, 2 + level / 3)
        if involvesTarget < required {
            return startRound()
        }
        let r = Round(ballCount: n, targetStartSlot: target, swaps: swaps, swapDuration: swapDuration)
        round = r
        return r
    }

    @discardableResult
    public mutating func pick(slot: Int, responseTime: Double?) -> AnswerResult {
        guard let r = round else { return .wrong }
        let isCorrect = slot == r.targetFinalSlot
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect { rawScore += Int((Double(15 + 3 * swapCount) * levelMultiplier).rounded()) }
        roundsPlayed += 1
        round = nil
        return isCorrect ? .correct : .wrong
    }
}
