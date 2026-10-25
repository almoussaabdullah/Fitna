import Foundation

/// Deterministic SplitMix64 generator. Every puzzle generator takes a
/// `RandomNumberGenerator`, so tests (and the daily workout) can reproduce
/// exactly the same puzzles from a seed.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Type-erased box so engines can hold "some generator" while staying value types.
public struct AnyRNG: RandomNumberGenerator {
    private var base: SeededGenerator

    public init(seed: UInt64) { base = SeededGenerator(seed: seed) }

    /// A non-deterministic seed for normal play.
    public static func fresh() -> AnyRNG {
        AnyRNG(seed: UInt64.random(in: 0...UInt64.max))
    }

    public mutating func next() -> UInt64 { base.next() }
}

public extension Array {
    /// Returns `count` distinct random elements (or all of them when count ≥ self.count).
    func randomSample<G: RandomNumberGenerator>(_ count: Int, using rng: inout G) -> [Element] {
        Array(shuffled(using: &rng).prefix(Swift.max(0, count)))
    }
}

/// Stable day key ("2026-10-25") computed in a given calendar/time zone.
public enum DayKey {
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Deterministic 64-bit seed for a day (FNV-1a over the day key).
    public static func seed(for date: Date, calendar: Calendar = .current, salt: String = "") -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in (key(for: date, calendar: calendar) + salt).utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
