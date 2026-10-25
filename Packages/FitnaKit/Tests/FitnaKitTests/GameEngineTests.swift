import XCTest
@testable import FitnaKit

final class NumberMemoryTests: XCTestCase {
    func testStartsWithThreeDigitsAndAdapts() {
        var e = NumberMemoryEngine(level: 1, rng: AnyRNG(seed: 1))
        XCTAssertEqual(e.currentLength, 3)
        let seq = e.startTrial()
        XCTAssertEqual(seq.count, 3)
        XCTAssertEqual(e.submit(seq, responseTime: 2), .correct)
        XCTAssertEqual(e.currentLength, 4)
        _ = e.startTrial()
        XCTAssertEqual(e.submit([9, 9, 9, 9, 9], responseTime: 2), .wrong)
        XCTAssertEqual(e.currentLength, 3)
        XCTAssertEqual(e.longestRecalled, 3)
        XCTAssertEqual(e.highlightValue, 3)
    }

    func testNeverBelowMinimumAndEndsAfterMistakes() {
        var e = NumberMemoryEngine(level: 1, rng: AnyRNG(seed: 2))
        for _ in 0..<3 {
            _ = e.startTrial()
            e.submit([], responseTime: 1)
            XCTAssertGreaterThanOrEqual(e.currentLength, 3)
        }
        XCTAssertTrue(e.isFinished)
        let o = e.outcome(duration: 20, completed: true)
        XCTAssertEqual(o.correct, 0)
        XCTAssertEqual(o.attempts, 3)
    }

    func testEndsAfterMaxTrials() {
        var e = NumberMemoryEngine(level: 4, length: .short, rng: AnyRNG(seed: 3))
        var trials = 0
        while !e.isFinished {
            let s = e.startTrial()
            e.submit(s, responseTime: 1)
            trials += 1
        }
        XCTAssertEqual(trials, e.maxTrials)
        XCTAssertGreaterThan(e.rawScore, 0)
    }

    func testHigherLevelsShowFasterAndStartLonger() {
        XCTAssertEqual(NumberMemoryEngine.startLength(level: 1), 3)
        XCTAssertEqual(NumberMemoryEngine.startLength(level: 10), 6)
        let low = NumberMemoryEngine(level: 1)
        let high = NumberMemoryEngine(level: 10)
        XCTAssertGreaterThan(low.secondsPerDigit, high.secondsPerDigit)
    }

    func testNoTripleRepeats() {
        var e = NumberMemoryEngine(level: 10, rng: AnyRNG(seed: 9))
        for _ in 0..<500 {
            let s = e.startTrial()
            for i in 2..<s.count { XCTAssertFalse(s[i] == s[i - 1] && s[i] == s[i - 2]) }
            e.submit(s, responseTime: 1)
            if e.isFinished { e = NumberMemoryEngine(level: 10, rng: AnyRNG(seed: UInt64(s.reduce(0, +)) + 7)) }
        }
    }

    func testDeterministicWithSeed() {
        var a = NumberMemoryEngine(level: 5, rng: AnyRNG(seed: 77))
        var b = NumberMemoryEngine(level: 5, rng: AnyRNG(seed: 77))
        XCTAssertEqual(a.startTrial(), b.startTrial())
    }
}

final class CardMatchingTests: XCTestCase {
    func testDeckHasPairs() {
        for level in 1...10 {
            let e = CardMatchingEngine(level: level, rng: AnyRNG(seed: UInt64(level)))
            XCTAssertEqual(e.cards.count, CardMatchingEngine.pairCount(level: level, length: .standard) * 2)
            let counts = Dictionary(grouping: e.cards, by: \.face).mapValues(\.count)
            XCTAssertTrue(counts.values.allSatisfy { $0 == 2 })
            XCTAssertEqual(e.cards.count % e.columns, 0, "grid must be rectangular")
        }
    }

    func testPerfectMemoryHasFullAccuracy() {
        var e = CardMatchingEngine(level: 5, rng: AnyRNG(seed: 11))
        // Simulate a player with perfect memory who explores unseen cards in order.
        var known: [Int: Int] = [:]  // face -> index seen
        var i = 0
        while !e.isFinished {
            let hidden = e.cards.indices.filter { e.cards[$0].state == .hidden }
            // If two known cards of the same face exist, match them.
            if let pair = Dictionary(grouping: hidden.filter { known.values.contains($0) }, by: { e.cards[$0].face }).values.first(where: { $0.count == 2 }) {
                _ = e.flip(pair[0]); _ = e.flip(pair[1])
                continue
            }
            let unseen = hidden.filter { !known.values.contains($0) }
            let first = unseen[0]
            _ = e.flip(first)
            known[first] = first
            let face = e.cards[first].face
            if let partner = hidden.first(where: { $0 != first && e.cards[$0].face == face && known.values.contains($0) }) {
                _ = e.flip(partner)
            } else {
                let second = unseen.dropFirst().first!
                let r = e.flip(second)
                known[second] = second
                if case .mismatch = r { e.hideMismatch() }
            }
            i += 1
            XCTAssertLessThan(i, 100)
        }
        let o = e.outcome(duration: 30, completed: true)
        XCTAssertEqual(o.accuracy, 1.0, "unavoidable first-look mismatches must not count")
        XCTAssertEqual(e.matchedPairs, e.pairCount)
    }

    func testAvoidableMismatchCounts() {
        var e = CardMatchingEngine(level: 1, rng: AnyRNG(seed: 5))
        let face0 = e.cards[0].face
        let partner = e.cards.indices.first { $0 != 0 && e.cards[$0].face == face0 }!
        let other = e.cards.indices.first { e.cards[$0].face != face0 }!
        // See card 0 and a non-matching card (free).
        _ = e.flip(0); _ = e.flip(other); e.hideMismatch()
        XCTAssertEqual(e.tally.attempts, 0)
        // See the partner with a different card (now card 0 was seen → avoidable).
        let third = e.cards.indices.first { $0 != 0 && $0 != partner && $0 != other && e.cards[$0].face != face0 }!
        _ = e.flip(partner)
        let r = e.flip(third)
        if case .mismatch = r {} else { XCTFail("expected mismatch") }
        XCTAssertEqual(e.tally.attempts, 1)
        XCTAssertEqual(e.tally.correct, 0)
    }

    func testIgnoresTapsWhileMismatchVisibleAndOnMatched() {
        var e = CardMatchingEngine(level: 1, rng: AnyRNG(seed: 6))
        let other = e.cards.indices.first { e.cards[$0].face != e.cards[0].face }!
        _ = e.flip(0); _ = e.flip(other)
        let third = e.cards.indices.first { $0 != 0 && $0 != other }!
        XCTAssertEqual(e.flip(third), .ignored)
        e.hideMismatch()
        XCTAssertEqual(e.flip(third), .firstCard)
        XCTAssertEqual(e.flip(third), .ignored, "can't flip the same card twice")
    }

    func testTimeUpCountsRemainingPairs() {
        var e = CardMatchingEngine(level: 3, rng: AnyRNG(seed: 8))
        e.timeUp()
        XCTAssertTrue(e.isFinished)
        XCTAssertEqual(e.tally.attempts, e.pairCount)
        XCTAssertEqual(e.outcome(duration: 30, completed: true).accuracy, 0)
    }
}

final class MentalMathTests: XCTestCase {
    func testExpressionsAreValidAtEveryLevel() {
        var rng = AnyRNG(seed: 21)
        for level in 1...10 {
            let spec = MathLevels.spec(level: level)
            for _ in 0..<2_000 {
                let e = MathLevels.expression(level: level, using: &rng)
                XCTAssertTrue(e.isValid)
                XCTAssertGreaterThanOrEqual(e.value, 0)
                XCTAssertTrue(spec.operators.contains(e.op))
                if e.op == .divide { XCTAssertEqual(e.lhs % e.rhs, 0) }
            }
        }
    }

    func testInputEvaluation() {
        var e = MentalMathEngine(level: 1, rng: AnyRNG(seed: 3))
        let answer = String(e.current.value)
        XCTAssertEqual(e.evaluate(answer), .correct)
        if answer.count > 1 { XCTAssertEqual(e.evaluate(String(answer.prefix(1))), .incomplete) }
        let wrong = String(repeating: answer.first == "9" ? "8" : "9", count: answer.count)
        XCTAssertEqual(e.evaluate(wrong), .wrong)
        XCTAssertEqual(e.commit(answer, responseTime: 1), .correct)
        XCTAssertGreaterThan(e.rawScore, 0)
    }

    func testWrongAnswerPenalty() {
        var e = MentalMathEngine(level: 2, rng: AnyRNG(seed: 4))
        e.commit(String(e.current.value), responseTime: 1)
        let before = e.rawScore
        e.commit("-1", responseTime: 1)
        XCTAssertEqual(e.rawScore, before - 5)
        XCTAssertEqual(e.tally.attempts, 2)
        XCTAssertEqual(e.tally.correct, 1)
        XCTAssertFalse(e.isFinished)
        e.timeUp()
        XCTAssertTrue(e.isFinished)
    }

    func testScoreNeverNegative() {
        var e = MentalMathEngine(level: 2, rng: AnyRNG(seed: 4))
        for _ in 0..<5 { e.commit("x", responseTime: 1) }
        XCTAssertEqual(e.rawScore, 0)
    }

    func testNoImmediateRepeat() {
        var e = MentalMathEngine(level: 1, rng: AnyRNG(seed: 99))
        for _ in 0..<300 {
            let prev = e.current
            e.commit(String(prev.value), responseTime: 1)
            XCTAssertNotEqual(prev, e.current)
        }
    }
}
