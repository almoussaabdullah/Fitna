import XCTest
@testable import FitnaKit

/// Generators are exercised with many seeds at every level: each puzzle must be
/// valid, solvable and have exactly one correct answer.
final class PuzzleGeneratorTests: XCTestCase {
    let seeds: [UInt64] = Array(1...40)

    func testMissingObjectRounds() {
        for level in 1...10 {
            for seed in seeds {
                var e = MissingObjectEngine(level: level, rng: AnyRNG(seed: seed))
                let r = e.startRound()
                XCTAssertEqual(r.objects.count, e.objectCount)
                XCTAssertEqual(Set(r.objects.map(\.slot)).count, r.objects.count, "slots unique")
                XCTAssertEqual(Set(r.objects.map(\.symbolIndex)).count, r.objects.count, "symbols unique")
                XCTAssertTrue(r.objects.allSatisfy { $0.slot < MissingObjectEngine.boardSlots })
                XCTAssertEqual(r.options.count, e.optionCount)
                XCTAssertEqual(Set(r.options).count, r.options.count)
                XCTAssertEqual(r.options.filter { $0 == r.missing.symbolIndex }.count, 1)
                // Distractors are never still on the board.
                let onBoard = Set(r.remaining.map(\.symbolIndex))
                XCTAssertTrue(r.options.allSatisfy { !onBoard.contains($0) })
                XCTAssertEqual(r.remaining.count, r.objects.count - 1)
                if e.singleColor { XCTAssertEqual(Set(r.objects.map(\.colorIndex)).count, 1) }
                XCTAssertEqual(e.answer(symbolIndex: r.missing.symbolIndex, responseTime: 1), .correct)
            }
        }
    }

    func testOddOneOutRounds() {
        for level in 1...10 {
            for seed in seeds {
                var e = OddOneOutEngine(level: level, rng: AnyRNG(seed: seed))
                let r = e.startRound()
                XCTAssertTrue((0..<r.cellCount).contains(r.oddIndex))
                switch r.difference {
                case .rotation(let deg): XCTAssertGreaterThanOrEqual(abs(deg), 15)
                case .shade(let a): XCTAssertGreaterThan(a, 0.05)
                case .size(let f): XCTAssertLessThan(f, 0.9)
                case .symbol(let odd): XCTAssertNotEqual(odd, r.baseSymbol)
                }
                XCTAssertEqual(e.tap(cell: (r.oddIndex + 1) % r.cellCount, responseTime: 1), .wrong)
            }
        }
        XCTAssertGreaterThan(OddOneOutEngine(level: 10).gridSize, OddOneOutEngine(level: 1).gridSize)
        XCTAssertLessThan(OddOneOutEngine(level: 10).rotationDegrees, OddOneOutEngine(level: 1).rotationDegrees)
    }

    func testOddOneOutSessionLength() {
        var e = OddOneOutEngine(level: 3, length: .short, rng: AnyRNG(seed: 1))
        while !e.isFinished {
            let r = e.startRound()
            e.tap(cell: r.oddIndex, responseTime: 1)
        }
        XCTAssertEqual(e.tally.attempts, 6)
        XCTAssertEqual(e.tally.correct, 6)
    }

    func testStroopStimuli() {
        for level in 1...10 {
            var e = StroopEngine(level: level, rng: AnyRNG(seed: UInt64(level)))
            var congruent = 0
            let n = 2_000
            var prevInk: StroopEngine.InkColor?
            for i in 0..<n {
                let s = e.stimulus
                XCTAssertEqual(s.choices.count, StroopEngine.colorCount(level: level))
                XCTAssertTrue(s.choices.contains(s.ink))
                XCTAssertTrue(s.choices.contains(s.word))
                if let p = prevInk { XCTAssertNotEqual(p, s.ink) }
                prevInk = s.ink
                if s.isCongruent { congruent += 1 }
                if i % 2 == 0 { e.answer(s.ink, responseTime: 1) } else { e.stimulusTimedOut() }
            }
            let rate = Double(congruent) / Double(n)
            XCTAssertEqual(rate, e.congruentProbability, accuracy: 0.05)
            XCTAssertEqual(e.tally.correct, n / 2)
        }
    }

    func testBallTrackingFinalSlot() {
        let swaps = [BallTrackingEngine.Swap(a: 0, b: 1), .init(a: 1, b: 2), .init(a: 0, b: 2)]
        XCTAssertEqual(BallTrackingEngine.finalSlot(start: 0, swaps: swaps), 0)
        XCTAssertEqual(BallTrackingEngine.finalSlot(start: 2, swaps: swaps), 1)
        for level in 1...10 {
            for seed in seeds {
                var e = BallTrackingEngine(level: level, rng: AnyRNG(seed: seed))
                let r = e.startRound()
                XCTAssertEqual(r.swaps.count, e.swapCount)
                for (i, s) in r.swaps.enumerated() {
                    XCTAssertNotEqual(s.a, s.b)
                    XCTAssertTrue(s.a < r.ballCount && s.b < r.ballCount)
                    if i > 0 { XCTAssertNotEqual(s, r.swaps[i - 1]) }
                }
                // Simulate positions explicitly and compare with the engine's answer.
                var slots = Array(0..<r.ballCount)   // slots[slot] = ball id
                for s in r.swaps { slots.swapAt(s.a, s.b) }
                XCTAssertEqual(slots.firstIndex(of: r.targetStartSlot), r.targetFinalSlot)
                XCTAssertEqual(e.pick(slot: r.targetFinalSlot, responseTime: 1), .correct)
            }
        }
    }

    func testPatternPuzzlesAreUnique() {
        for level in 1...10 {
            for seed in seeds {
                var e = PatternCompletionEngine(level: level, rng: AnyRNG(seed: seed))
                let p = e.startRound()
                XCTAssertTrue(PatternCompletionEngine.isUniquelyDetermined(p))
                XCTAssertEqual(p.options.count, 4)
                XCTAssertEqual(p.options.filter { $0 == p.answer }.count, 1)
                // Every item follows the rules.
                for (i, item) in p.items.enumerated() {
                    XCTAssertEqual(item.color, p.rules["color"]!.value(at: i))
                    XCTAssertEqual(item.shape, p.rules["shape"]!.value(at: i))
                    XCTAssertEqual(item.count, p.rules["count"]!.value(at: i))
                    XCTAssertEqual(item.rotation, p.rules["rotation"]!.value(at: i))
                    XCTAssertTrue((1...4).contains(item.count))
                    XCTAssertEqual(item.rotation % 45, 0)
                }
                // The hidden attributes can be read from visible items with the same cycle phase.
                for (name, rule) in p.rules {
                    if case .cycle(let values) = rule {
                        let period = values.count
                        let witness = p.items.indices.first { $0 != p.missingIndex && $0 % period == p.missingIndex % period }
                        XCTAssertNotNil(witness, "\(name) not derivable")
                    }
                }
                let idx = p.options.firstIndex(of: p.answer)!
                XCTAssertEqual(e.answer(optionIndex: idx, responseTime: 2), .correct)
            }
        }
    }

    func testBalancePuzzlesSolveUniquely() {
        for level in 1...10 {
            for seed in seeds {
                var e = BalanceLogicEngine(level: level, rng: AnyRNG(seed: seed))
                let p = e.startRound()
                XCTAssertEqual(p.objects.count, e.objectCount)
                XCTAssertEqual(BalanceLogicEngine.solve(p), p.answer)
                XCTAssertGreaterThanOrEqual(p.clues.count, p.objects.count - 1)
                XCTAssertTrue(p.clues.allSatisfy { $0.heavier != $0.lighter })
                // Removing all clues must make the answer underivable (clues matter).
                let empty = BalanceLogicEngine.Puzzle(objects: p.objects, clues: [], question: p.question, answer: p.answer, visualScales: false)
                XCTAssertNil(BalanceLogicEngine.solve(empty))
                XCTAssertEqual(e.answer(objectIndex: p.answer, responseTime: 3), .correct)
            }
        }
    }

    func testBalanceSolverRejectsAmbiguity() {
        let objs = Array(BalanceLogicEngine.catalog.prefix(3))
        // A > B and A > C: heaviest is A, lightest is ambiguous.
        let clues = [BalanceLogicEngine.Clue(heavier: 0, lighter: 1, phrasedAsLighter: false),
                     BalanceLogicEngine.Clue(heavier: 0, lighter: 2, phrasedAsLighter: false)]
        XCTAssertEqual(BalanceLogicEngine.solve(.init(objects: objs, clues: clues, question: .heaviest, answer: 0, visualScales: false)), 0)
        XCTAssertNil(BalanceLogicEngine.solve(.init(objects: objs, clues: clues, question: .lightest, answer: 1, visualScales: false)))
    }

    func testMissingNumberPuzzlesUnambiguous() {
        for level in 1...10 {
            for seed in seeds {
                var e = MissingNumberEngine(level: level, rng: AnyRNG(seed: seed))
                let p = e.startRound()
                XCTAssertTrue(MissingNumberEngine.isValid(p))
                XCTAssertTrue(MissingNumberEngine.follows(p.terms, p.family), "terms must follow their own family")
                XCTAssertEqual(p.options.count, 4)
                XCTAssertGreaterThan(p.missingIndex, 0)
                XCTAssertTrue(p.terms.allSatisfy { $0 >= 0 })
                if level <= 4 { XCTAssertEqual(p.missingIndex, p.terms.count - 1) }
                XCTAssertEqual(e.answer(p.answer, responseTime: 4), .correct)
            }
        }
    }

    func testMissingNumberFamilyDetectors() {
        XCTAssertTrue(MissingNumberEngine.follows([2, 4, 8, 16, 32], .geometric))
        XCTAssertTrue(MissingNumberEngine.follows([3, 6, 11, 18, 27], .quadratic))
        XCTAssertTrue(MissingNumberEngine.follows([1, 1, 2, 3, 5, 8], .fibonacci))
        XCTAssertTrue(MissingNumberEngine.follows([1, 10, 2, 20, 3, 30], .interleaved))
        XCTAssertTrue(MissingNumberEngine.follows([1, 3, 7, 15, 31], .multiplyAdd))
        XCTAssertFalse(MissingNumberEngine.follows([2, 4, 8, 15, 32], .geometric))
        XCTAssertFalse(MissingNumberEngine.follows([1, 2, 4, 7, 12], .quadratic))
    }

    func testValueComparisonPairs() {
        for level in 1...10 {
            var e = ValueComparisonEngine(level: level, rng: AnyRNG(seed: UInt64(level * 13)))
            let gap = ValueComparisonEngine.gapRange(level: level)
            while !e.isFinished {
                let p = e.pair
                XCTAssertNotEqual(p.first.value, p.second.value)
                XCTAssertTrue(p.first.isValid && p.second.isValid)
                let rel = Double(abs(p.first.value - p.second.value)) / Double(max(p.first.value, p.second.value))
                XCTAssertTrue(gap.contains(rel), "level \(level) gap \(rel)")
                e.choose(p.larger, responseTime: 1)
            }
            XCTAssertEqual(e.tally.correct, e.totalTrials)
        }
    }

    func testSortingRounds() {
        for level in 1...10 {
            for seed in seeds.prefix(15) {
                var e = SortingChallengeEngine(level: level, rng: AnyRNG(seed: seed))
                var rulesSeen: [SortingChallengeEngine.Rule] = []
                while !e.isFinished {
                    let r = e.startRound()
                    rulesSeen.append(r.rule)
                    XCTAssertTrue(SortingChallengeEngine.availableRules(level: level).contains(r.rule))
                    XCTAssertEqual(r.items.count, e.itemCount)
                    XCTAssertEqual(Set(r.expectedOrder), Set(r.items.map(\.id)))
                    XCTAssertEqual(Set(r.items.map(\.value)).count, r.items.count, "values distinct")
                    let byID = Dictionary(uniqueKeysWithValues: r.items.map { ($0.id, $0) })
                    let ordered = r.expectedOrder.map { byID[$0]! }
                    switch r.rule {
                    case .ascending, .alphabetical:
                        XCTAssertEqual(ordered.map(\.value), ordered.map(\.value).sorted())
                    case .descending:
                        XCTAssertEqual(ordered.map(\.value), ordered.map(\.value).sorted(by: >))
                    case .alternatingColors:
                        for (i, item) in ordered.enumerated() {
                            XCTAssertEqual(item.colorGroup, i % 2 == 0 ? r.startGroup : 1 - r.startGroup)
                        }
                        for g in 0...1 {
                            let vals = ordered.filter { $0.colorGroup == g }.map(\.value)
                            XCTAssertEqual(vals, vals.sorted())
                        }
                    }
                    // A wrong tap doesn't advance.
                    if let wrong = r.expectedOrder.dropFirst().first {
                        XCTAssertEqual(e.tap(itemID: wrong, responseTime: 1), .wrong)
                        XCTAssertEqual(e.progress, 0)
                    }
                    for id in r.expectedOrder { XCTAssertEqual(e.tap(itemID: id, responseTime: 0.5), .correct) }
                    XCTAssertTrue(e.roundComplete)
                }
                if level >= 5 {
                    for i in 1..<rulesSeen.count { XCTAssertNotEqual(rulesSeen[i], rulesSeen[i - 1]) }
                } else {
                    XCTAssertEqual(Set(rulesSeen).count, 1)
                }
            }
        }
    }

    func testArabicAlphabetComplete() {
        XCTAssertEqual(SortingChallengeEngine.arabicLetters.count, 28)
        XCTAssertEqual(Set(SortingChallengeEngine.arabicLetters).count, 28)
    }

    func testOutcomesFeedScoring() {
        var e = MissingNumberEngine(level: 6, length: .short, rng: AnyRNG(seed: 3))
        while !e.isFinished {
            let p = e.startRound()
            e.answer(p.answer, responseTime: 5)
        }
        let o = e.outcome(duration: 40, completed: true)
        XCTAssertEqual(o.attempts, 5)
        XCTAssertEqual(o.accuracy, 1)
        XCTAssertEqual(o.length, .short)
        XCTAssertNotNil(ScoringModel.performance(o))
    }
}
