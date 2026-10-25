import Foundation

/// أكمل النمط — find the missing element of a visual sequence.
///
/// Each item has four attributes: shape, color, rotation and count. Every attribute
/// follows its own rule (constant, a cycle, or a step progression). Sequences always
/// show at least two full periods of every cycle and three items of every progression,
/// and `isUniquelyDetermined` verifies the hidden item can be derived from the visible
/// ones before a puzzle is used.
public struct PatternCompletionEngine: GameEngine {
    public struct Item: Hashable, Sendable {
        public var shape: Int      // index into SymbolCatalog.patternShapes (or directional when rotating)
        public var color: Int      // palette index 0..<4
        public var rotation: Int   // degrees, multiple of 45
        public var count: Int      // 1...4
        public var usesDirectionalShape: Bool

        public var symbolName: String {
            usesDirectionalShape ? SymbolCatalog.directional[shape % SymbolCatalog.directional.count]
                                 : SymbolCatalog.patternShapes[shape % SymbolCatalog.patternShapes.count]
        }
    }

    public enum Rule: Equatable, Sendable {
        case constant(Int)
        case cycle([Int])
        /// value(i) = (start + step·i) mod modulus  (rotation) or start + step·i (count)
        case progression(start: Int, step: Int, modulus: Int?)

        public func value(at i: Int) -> Int {
            switch self {
            case .constant(let v): return v
            case .cycle(let values): return values[i % values.count]
            case .progression(let start, let step, let modulus):
                let raw = start + step * i
                guard let m = modulus else { return raw }
                return ((raw % m) + m) % m
            }
        }

        var period: Int? {
            if case .cycle(let v) = self { return v.count }
            return nil
        }
    }

    public struct Puzzle: Equatable, Sendable {
        public let items: [Item]           // full sequence including the hidden one
        public let missingIndex: Int
        public let options: [Item]         // includes the answer exactly once
        public let rules: [String: Rule]   // "shape", "color", "rotation", "count"
        public var answer: Item { items[missingIndex] }
    }

    public let gameID = GameID.patternCompletion
    public let level: Int
    public let length: SessionLength
    public private(set) var tally = AnswerTally()
    public private(set) var rawScore = 0
    public private(set) var puzzle: Puzzle?
    public private(set) var roundsPlayed = 0
    private var rng: AnyRNG

    public init(level: Int, length: SessionLength = .standard, rng: AnyRNG = .fresh()) {
        self.level = Difficulty.clamp(level)
        self.length = length
        self.rng = rng
    }

    public var totalRounds: Int { length == .standard ? 8 : 5 }
    public var isFinished: Bool { roundsPlayed >= totalRounds }

    @discardableResult
    public mutating func startRound() -> Puzzle {
        for _ in 0..<200 {
            let p = PatternCompletionEngine.generate(level: level, rng: &rng)
            if PatternCompletionEngine.isUniquelyDetermined(p) {
                puzzle = p
                return p
            }
        }
        // Fallback that is always valid: a simple two-color alternation.
        let p = PatternCompletionEngine.simpleFallback()
        puzzle = p
        return p
    }

    @discardableResult
    public mutating func answer(optionIndex: Int, responseTime: Double?) -> AnswerResult {
        guard let p = puzzle, p.options.indices.contains(optionIndex) else { return .wrong }
        let isCorrect = p.options[optionIndex] == p.answer
        tally.record(correct: isCorrect, responseTime: responseTime)
        if isCorrect { rawScore += Int((Double(20 + 2 * level) * levelMultiplier).rounded()) }
        roundsPlayed += 1
        puzzle = nil
        return isCorrect ? .correct : .wrong
    }

    // MARK: Generation

    static func generate(level: Int, rng: inout AnyRNG) -> Puzzle {
        // Which attributes vary at this level.
        var varying: [String]
        switch level {
        case 1...2: varying = [["color", "shape"].randomElement(using: &rng)!]
        case 3...4: varying = [["color", "shape", "rotation"].randomElement(using: &rng)!]
        case 5...6: varying = Array(["color", "shape", "count", "rotation"].shuffled(using: &rng).prefix(Int.random(in: 1...2, using: &rng)))
        case 7...8: varying = Array(["color", "shape", "count", "rotation"].shuffled(using: &rng).prefix(2))
        default: varying = Array(["color", "shape", "count", "rotation"].shuffled(using: &rng).prefix(3))
        }
        if level >= 5 && varying.count == 1 && varying[0] == "color" { varying.append("count") }

        let maxPeriod = level <= 2 ? 2 : level <= 6 ? 3 : 3
        func cycle(_ pool: [Int]) -> Rule {
            let period = level <= 2 ? 2 : Int.random(in: 2...maxPeriod, using: &rng)
            let values = Array(pool.shuffled(using: &rng).prefix(period))
            return .cycle(values)
        }

        let usesDirectional = varying.contains("rotation")
        let shapePool = Array(0..<(usesDirectional ? SymbolCatalog.directional.count : SymbolCatalog.patternShapes.count))
        var rules: [String: Rule] = [:]
        rules["shape"] = varying.contains("shape") ? cycle(shapePool) : .constant(shapePool.randomElement(using: &rng)!)
        rules["color"] = varying.contains("color") ? cycle([0, 1, 2, 3]) : .constant(Int.random(in: 0..<4, using: &rng))
        if varying.contains("rotation") {
            let step = level >= 7 ? [45, 90, -45].randomElement(using: &rng)! : [90, -90].randomElement(using: &rng)!
            rules["rotation"] = .progression(start: [0, 90, 180, 270].randomElement(using: &rng)!, step: step, modulus: 360)
        } else {
            rules["rotation"] = .constant(0)
        }
        if varying.contains("count") {
            // Either a growing count (1,2,3,4) restricted to fit, or a count cycle.
            if Bool.random(using: &rng) {
                rules["count"] = cycle([1, 2, 3])
            } else {
                rules["count"] = .cycle([1, 2, 3, 4])
            }
        } else {
            rules["count"] = .constant(1)
        }

        // Length: two full periods of the longest cycle plus room for the gap.
        let longest = rules.values.compactMap(\.period).max() ?? 2
        let total = max(6, 2 * longest + 2)
        let items = (0..<total).map { i in
            Item(shape: rules["shape"]!.value(at: i), color: rules["color"]!.value(at: i),
                 rotation: rules["rotation"]!.value(at: i), count: rules["count"]!.value(at: i),
                 usesDirectionalShape: usesDirectional)
        }
        let missingIndex = level <= 4 ? total - 1 : Int.random(in: (total / 2)...(total - 1), using: &rng)
        let answer = items[missingIndex]

        // Distractors: tweak one or two attributes of the answer.
        var options: Set<Item> = [answer]
        var attempts = 0
        while options.count < 4 && attempts < 100 {
            attempts += 1
            var d = answer
            let tweaks = level >= 6 ? Int.random(in: 1...2, using: &rng) : 1
            for attr in ["shape", "color", "rotation", "count"].shuffled(using: &rng).prefix(tweaks) {
                switch attr {
                case "shape": d.shape = (d.shape + Int.random(in: 1..<shapePool.count, using: &rng)) % shapePool.count
                case "color": d.color = (d.color + Int.random(in: 1..<4, using: &rng)) % 4
                case "rotation":
                    // Rotating a non-directional shape is invisible, so only tweak visible rotations.
                    guard usesDirectional else { continue }
                    d.rotation = (d.rotation + [45, 90, 180, 270].randomElement(using: &rng)!) % 360
                default: d.count = d.count % 4 + 1
                }
            }
            if d != answer { options.insert(d) }
        }
        let ordered = Array(options).sorted { "\($0)" < "\($1)" }.shuffled(using: &rng)
        return Puzzle(items: items, missingIndex: missingIndex, options: ordered, rules: rules)
    }

    /// True when every attribute of the hidden item follows from the visible items:
    /// cycles must show ≥ 2 full periods and the hidden position's residue class must be
    /// visible; progressions need ≥ 2 visible consecutive items to read the step.
    /// Also requires all options to be visually distinct and to contain the answer once.
    public static func isUniquelyDetermined(_ p: Puzzle) -> Bool {
        let n = p.items.count
        let visible = (0..<n).filter { $0 != p.missingIndex }
        for (_, rule) in p.rules {
            switch rule {
            case .constant: continue
            case .cycle(let values):
                let period = values.count
                if n - 1 < 2 * period { return false }
                // Values within a cycle must be distinct, otherwise the period is ambiguous.
                if Set(values).count != period { return false }
                let sameClass = visible.filter { $0 % period == p.missingIndex % period }
                if sameClass.isEmpty { return false }
            case .progression:
                // Need two consecutive visible items to read the step.
                let pairs = visible.filter { visible.contains($0 + 1) }
                if pairs.isEmpty { return false }
            }
        }
        // Hidden item must be visually distinct from its neighbors' alternatives.
        let distinct = Set(p.options.map(VisualKey.init))
        guard distinct.count == p.options.count else { return false }
        guard p.options.filter({ $0 == p.answer }).count == 1 else { return false }
        return true
    }

    /// Equality as the player perceives it (rotation is invisible on symmetric shapes).
    struct VisualKey: Hashable {
        let shape: Int, color: Int, rotation: Int, count: Int
        init(_ item: Item) {
            shape = item.shape
            color = item.color
            rotation = item.usesDirectionalShape ? item.rotation : 0
            count = item.count
        }
    }

    static func simpleFallback() -> Puzzle {
        let rules: [String: Rule] = ["shape": .constant(0), "color": .cycle([0, 1]), "rotation": .constant(0), "count": .constant(1)]
        let items = (0..<6).map { Item(shape: 0, color: $0 % 2, rotation: 0, count: 1, usesDirectionalShape: false) }
        let answer = items[5]
        let options = [answer,
                       Item(shape: 0, color: 0, rotation: 0, count: 1, usesDirectionalShape: false),
                       Item(shape: 1, color: 1, rotation: 0, count: 1, usesDirectionalShape: false),
                       Item(shape: 0, color: 2, rotation: 0, count: 1, usesDirectionalShape: false)]
        return Puzzle(items: items, missingIndex: 5, options: options, rules: rules)
    }
}
