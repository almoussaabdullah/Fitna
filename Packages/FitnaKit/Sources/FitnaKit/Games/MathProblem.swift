import Foundation

public enum MathOperator: String, Codable, Sendable, CaseIterable {
    case add = "+"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"

    public func apply(_ a: Int, _ b: Int) -> Int? {
        switch self {
        case .add: return a + b
        case .subtract: return a - b
        case .multiply: return a * b
        case .divide: return b != 0 && a % b == 0 ? a / b : nil
        }
    }
}

/// A two-operand integer expression. Text is always left-to-right
/// ("24 + 18") and must be rendered in an LTR context inside RTL layouts.
public struct MathExpression: Equatable, Sendable {
    public let lhs: Int
    public let op: MathOperator
    public let rhs: Int

    public init(_ lhs: Int, _ op: MathOperator, _ rhs: Int) {
        self.lhs = lhs
        self.op = op
        self.rhs = rhs
    }

    public var value: Int { op.apply(lhs, rhs) ?? 0 }
    public var isValid: Bool { op.apply(lhs, rhs) != nil }
    public var text: String { "\(lhs) \(op.rawValue) \(rhs)" }
}

/// Number ranges per level shared by حساب البرق and الأكبر أم الأصغر.
public enum MathLevels {
    public struct Spec: Sendable {
        public let operators: [MathOperator]
        public let addMax: Int          // operands for + and −
        public let mulA: ClosedRange<Int>
        public let mulB: ClosedRange<Int>
    }

    public static func spec(level: Int) -> Spec {
        switch Difficulty.clamp(level) {
        case 1: return Spec(operators: [.add, .subtract], addMax: 9, mulA: 2...5, mulB: 2...5)
        case 2: return Spec(operators: [.add, .subtract], addMax: 20, mulA: 2...5, mulB: 2...5)
        case 3: return Spec(operators: [.add, .subtract, .multiply], addMax: 40, mulA: 2...5, mulB: 2...9)
        case 4: return Spec(operators: [.add, .subtract, .multiply], addMax: 60, mulA: 2...9, mulB: 2...9)
        case 5: return Spec(operators: MathOperator.allCases, addMax: 99, mulA: 2...9, mulB: 2...9)
        case 6: return Spec(operators: MathOperator.allCases, addMax: 150, mulA: 2...12, mulB: 2...12)
        case 7: return Spec(operators: MathOperator.allCases, addMax: 250, mulA: 6...19, mulB: 2...9)
        case 8: return Spec(operators: MathOperator.allCases, addMax: 400, mulA: 11...25, mulB: 3...9)
        case 9: return Spec(operators: MathOperator.allCases, addMax: 700, mulA: 11...19, mulB: 11...15)
        default: return Spec(operators: MathOperator.allCases, addMax: 999, mulA: 12...25, mulB: 11...19)
        }
    }

    /// Random valid expression at a level. Subtraction never goes negative and
    /// division is always exact, so every answer is a non-negative integer.
    public static func expression<G: RandomNumberGenerator>(level: Int, op forced: MathOperator? = nil, using rng: inout G) -> MathExpression {
        let s = spec(level: level)
        let op = forced ?? s.operators.randomElement(using: &rng)!
        let low = level <= 2 ? 1 : max(2, s.addMax / 10)
        switch op {
        case .add:
            return MathExpression(Int.random(in: low...s.addMax, using: &rng), .add, Int.random(in: low...s.addMax, using: &rng))
        case .subtract:
            let a = Int.random(in: low...s.addMax, using: &rng)
            let b = Int.random(in: low...s.addMax, using: &rng)
            return MathExpression(max(a, b), .subtract, min(a, b))
        case .multiply:
            return MathExpression(Int.random(in: s.mulA, using: &rng), .multiply, Int.random(in: s.mulB, using: &rng))
        case .divide:
            let divisor = Int.random(in: s.mulB, using: &rng)
            let quotient = Int.random(in: s.mulA, using: &rng)
            return MathExpression(divisor * quotient, .divide, divisor)
        }
    }
}
