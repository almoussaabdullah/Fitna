import Foundation
import Observation
import FitnaKit

/// Pause-aware clock measuring *active* play time in seconds.
/// Games read `now` for deadlines and response times, so pausing freezes everything.
@Observable
final class GameClock {
    private(set) var isPaused = false
    private var accumulated: Double = 0
    private var resumedAt: Date?

    var now: Double {
        guard let r = resumedAt, !isPaused else { return accumulated }
        return accumulated + Date().timeIntervalSince(r)
    }

    func start() {
        accumulated = 0
        isPaused = false
        resumedAt = Date()
    }

    func pause() {
        guard !isPaused else { return }
        accumulated = now
        isPaused = true
        resumedAt = nil
    }

    func resume() {
        guard isPaused else { return }
        isPaused = false
        resumedAt = Date()
    }
}

/// What every mini-game view model exposes to the shared game host.
@MainActor
protocol GameViewModel: AnyObject {
    var gameID: GameID { get }
    var level: Int { get }
    var length: SessionLength { get }
    var isFinished: Bool { get }
    /// Live score for the HUD.
    var hudScore: Int { get }
    /// e.g. "3 / 10" — nil for timed games.
    var hudProgress: String? { get }
    /// Remaining fraction of the session timer (1 → 0), nil when untimed.
    var hudTimeFraction: Double? { get }
    /// Called once when play starts.
    func begin()
    /// Called ~30×/s while not paused.
    func tick()
    func outcome(duration: Double, completed: Bool) -> SessionOutcome
}

/// Transient feedback flash shared by games.
enum AnswerFlash: Equatable {
    case none, correct, wrong
}

extension GameViewModel {
    func progressText(_ current: Int, _ total: Int) -> String {
        "\(min(current + 1, total)) / \(total)"
    }
}

/// Builds the right view model for a game.
@MainActor
enum GameFactory {
    static func makeViewModel(for game: GameID, level: Int, length: SessionLength, clock: GameClock) -> any GameViewModel {
        switch game {
        case .numberMemory: return NumberMemoryViewModel(level: level, length: length, clock: clock)
        case .missingObject: return MissingObjectViewModel(level: level, length: length, clock: clock)
        case .cardMatching: return CardMatchingViewModel(level: level, length: length, clock: clock)
        case .oddOneOut: return OddOneOutViewModel(level: level, length: length, clock: clock)
        case .stroopChallenge: return StroopViewModel(level: level, length: length, clock: clock)
        case .ballTracking: return BallTrackingViewModel(level: level, length: length, clock: clock)
        case .patternCompletion: return PatternViewModel(level: level, length: length, clock: clock)
        case .balanceLogic: return BalanceViewModel(level: level, length: length, clock: clock)
        case .missingNumber: return MissingNumberViewModel(level: level, length: length, clock: clock)
        case .mentalMath: return MentalMathViewModel(level: level, length: length, clock: clock)
        case .valueComparison: return ValueComparisonViewModel(level: level, length: length, clock: clock)
        case .sortingChallenge: return SortingViewModel(level: level, length: length, clock: clock)
        }
    }
}
