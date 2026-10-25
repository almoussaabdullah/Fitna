import Foundation

/// أين اختفت؟ — memorize a set of objects, then spot which one disappeared.
///
/// Objects sit on a 4×4 board. After the memorize phase the same arrangement is
/// shown with one object removed (its slot left empty) and the player picks the
/// missing object from a set of options. Distractor options are never objects
/// that are still on the board, and at higher levels they come from the same
/// visual family as the missing object.
public struct MissingObjectEngine: GameEngine {
    public struct PlacedObject: Equatable, Sendable {
        public let slot: Int          // 0..<16
        public let symbolIndex: Int   // index into SymbolCatalog.objects
        public let colorIndex: Int    // index into the design-system accent palette
    }

    public struct Round: Equatable, Sendable {
        public let objects: [PlacedObject]
        public let missing: PlacedObject
        /// Option symbol indices (includes the missing one exactly once).
        public let options: [Int]
        public var remaining: [PlacedObject] { objects.filter { $0 != missing } }
    }

    public let gameID = GameID.missingObject
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var round: Round?
    public private(set) var roundsPlayed = 0
    private var rng: AnyRNG

    public static let boardSlots = 16
    public static let paletteSize = 4

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        self.level = Difficulty.clamp(level)
        self.length = length
        self.rng = rng
    }

    public var totalRounds: Int { length == .standard ? 8 : 5 }
    public var objectCount: Int { 4 + Int((Double(level - 1) * 0.9).rounded()) }
    public var optionCount: Int { level <= 4 ? 4 : 6 }
    public var memorizeDuration: Double { max(2.0, 1.5 + Double(objectCount) * 0.45 - Double(level - 1) * 0.2) }
    /// From level 7 every object shares one color, so only shape can be remembered.
    public var singleColor: Bool { level >= 7 }
    public var isFinished: Bool { roundsPlayed >= totalRounds }

    @discardableResult
    public mutating func startRound() -> Round {
        let catalog = SymbolCatalog.objects
        let symbols = Array(catalog.indices).randomSample(objectCount, using: &rng)
        let slots = Array(0..<MissingObjectEngine.boardSlots).randomSample(objectCount, using: &rng)
        let sharedColor = Int.random(in: 0..<MissingObjectEngine.paletteSize, using: &rng)
        let objects = zip(slots, symbols).map { slot, sym in
            PlacedObject(slot: slot, symbolIndex: sym,
                         colorIndex: singleColor ? sharedColor : Int.random(in: 0..<MissingObjectEngine.paletteSize, using: &rng))
        }
        let missing = objects.randomElement(using: &rng)!
        let shown = Set(symbols)
        var pool = catalog.indices.filter { !shown.contains($0) }
        if level >= 5 {
            // Prefer look-alikes from the missing object's family.
            let family = catalog[missing.symbolIndex].family
            let same = pool.filter { catalog[$0].family == family }.shuffled(using: &rng)
            let others = pool.filter { catalog[$0].family != family }.shuffled(using: &rng)
            pool = same + others
        } else {
            pool.shuffle(using: &rng)
        }
        let distractors = Array(pool.prefix(optionCount - 1))
        let options = (distractors + [missing.symbolIndex]).shuffled(using: &rng)
        let r = Round(objects: objects, missing: missing, options: options)
        round = r
        return r
    }

    @discardableResult
    public mutating func answer(symbolIndex: Int, responseTime: Double?) -> AnswerResult {
        guard let r = round else { return .wrong }
        let isCorrect = symbolIndex == r.missing.symbolIndex
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect { rawScore += Int((Double(15 + 3 * objectCount) * levelMultiplier).rounded()) }
        roundsPlayed += 1
        round = nil
        return isCorrect ? .correct : .wrong
    }
}
