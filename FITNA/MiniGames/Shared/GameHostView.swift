import SwiftUI
import SwiftData
import FitnaKit

/// How a game was launched.
enum GameLaunch: Equatable {
    /// Standalone play at the player's adaptive level, with a results screen.
    case free
    /// Part of the daily workout (short session, adaptive level).
    case workout
    /// Part of the brain test (short session, fixed calibrated level).
    case assessment(level: Int)

    var context: PlayContext {
        switch self {
        case .free: return .free
        case .workout: return .workout
        case .assessment: return .assessment
        }
    }

    var length: SessionLength { self == .free ? .standard : .short }
}

/// Shared shell for every mini-game: tutorial → countdown → play (with HUD and pause)
/// → recording → results. The game-specific view sits in the middle.
struct GameHostView: View {
    let game: GameID
    let launch: GameLaunch
    /// Called when the player leaves (exit or after results).
    var onExit: () -> Void
    /// For workout/assessment: called with the recorded summary instead of showing results.
    var onCompleted: ((RecordSummary) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.showTutorials) private var alwaysShowTutorials = false
    @AppStorage("seenTutorials") private var seenTutorialsRaw = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Phase: Equatable {
        case tutorial, countdown(Int), playing, finished
    }

    @State private var phase: Phase = .tutorial
    @State private var clock = GameClock()
    @State private var model: (any GameViewModel)?
    @State private var level = 1
    @State private var startedAt = Date()
    @State private var showPause = false
    @State private var summary: RecordSummary?
    @State private var recorded = false

    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch phase {
            case .tutorial:
                GameTutorialView(game: game, level: level, launch: launch,
                                 onStart: startCountdown,
                                 onClose: exitWithoutPlaying)
                    .transition(.opacity)
            case .countdown(let n):
                CountdownView(value: n, tint: game.color)
                    .transition(.opacity)
            case .playing:
                if let model {
                    VStack(spacing: 0) {
                        GameHUD(game: game, level: level, model: model, clock: clock, onPause: pause)
                        GamePlayView(model: model)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(!showPause)
                    }
                    .transition(.opacity)
                }
            case .finished:
                if let summary, launch == .free {
                    GameResultsView(summary: summary, onReplay: replay, onExit: onExit)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    ProgressView().tint(Theme.purple)
                }
            }

            if showPause {
                PauseOverlay(game: game,
                             onResume: resume,
                             onRestart: restart,
                             onExit: exitMidGame)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: phase)
        .animation(.easeInOut(duration: 0.2), value: showPause)
        .onAppear(perform: prepare)
        .onReceive(ticker) { _ in
            guard phase == .playing, let model, !clock.isPaused else { return }
            model.tick()
            if model.isFinished { finish() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active, phase == .playing, !showPause { pause() }
        }
        .statusBarHidden(phase == .playing)
    }

    // MARK: Flow

    private func prepare() {
        switch launch {
        case .assessment(let l): level = Difficulty.clamp(l)
        default: level = Store.difficulty(for: game, in: modelContext).difficulty.level
        }
        let seen = Set(seenTutorialsRaw.split(separator: ",").map(String.init))
        // Workout/assessment always show the short how-to; free play only the first time.
        if launch == .free && seen.contains(game.rawValue) && !alwaysShowTutorials {
            startCountdown()
        } else {
            phase = .tutorial
        }
    }

    private func startCountdown() {
        var seen = Set(seenTutorialsRaw.split(separator: ",").map(String.init))
        seen.insert(game.rawValue)
        seenTutorialsRaw = seen.sorted().joined(separator: ",")
        Task { @MainActor in
            for n in stride(from: 3, through: 1, by: -1) {
                phase = .countdown(n)
                Feedback.tick()
                try? await Task.sleep(nanoseconds: 650_000_000)
            }
            beginPlay()
        }
    }

    private func beginPlay() {
        let m = GameFactory.makeViewModel(for: game, level: level, length: launch.length, clock: clock)
        model = m
        recorded = false
        summary = nil
        startedAt = Date()
        clock.start()
        Feedback.start()
        phase = .playing
        m.begin()
    }

    private func pause() {
        clock.pause()
        showPause = true
    }

    private func resume() {
        showPause = false
        clock.resume()
    }

    private func restart() {
        recordAbandonedIfNeeded()
        showPause = false
        model = nil
        startCountdown()
    }

    private func exitMidGame() {
        recordAbandonedIfNeeded()
        showPause = false
        onExit()
    }

    private func exitWithoutPlaying() { onExit() }

    private func replay() {
        level = Store.difficulty(for: game, in: modelContext).difficulty.level
        model = nil
        startCountdown()
    }

    private func finish() {
        guard !recorded, let model else { return }
        recorded = true
        clock.pause()
        let outcome = model.outcome(duration: clock.now, completed: true)
        let result = GameRecorder.record(outcome, context: launch.context, startedAt: startedAt, in: modelContext)
        summary = result
        if result.leveledUp || !result.newAchievements.isEmpty { Feedback.levelUp() } else { Feedback.success() }
        if let onCompleted, launch != .free {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                onCompleted(result)
            }
        }
        phase = .finished
    }

    /// Quitting still counts toward play time, but never toward scores or difficulty.
    private func recordAbandonedIfNeeded() {
        guard !recorded, let model, phase == .playing else { return }
        recorded = true
        let outcome = model.outcome(duration: clock.now, completed: false)
        guard outcome.attempts > 0 || outcome.duration > 5 else { return }
        GameRecorder.record(outcome, context: launch.context, startedAt: startedAt, in: modelContext)
    }
}

/// Routes a view model to its game view.
struct GamePlayView: View {
    let model: any GameViewModel

    var body: some View {
        Group {
            if let m = model as? NumberMemoryViewModel { NumberMemoryView(model: m) }
            else if let m = model as? MissingObjectViewModel { MissingObjectView(model: m) }
            else if let m = model as? CardMatchingViewModel { CardMatchingView(model: m) }
            else if let m = model as? OddOneOutViewModel { OddOneOutView(model: m) }
            else if let m = model as? StroopViewModel { StroopView(model: m) }
            else if let m = model as? BallTrackingViewModel { BallTrackingView(model: m) }
            else if let m = model as? PatternViewModel { PatternView(model: m) }
            else if let m = model as? BalanceViewModel { BalanceView(model: m) }
            else if let m = model as? MissingNumberViewModel { MissingNumberView(model: m) }
            else if let m = model as? MentalMathViewModel { MentalMathView(model: m) }
            else if let m = model as? ValueComparisonViewModel { ValueComparisonView(model: m) }
            else if let m = model as? SortingViewModel { SortingView(model: m) }
        }
        .padding(.horizontal, Theme.padding)
        .padding(.bottom, 12)
    }
}

// MARK: - HUD

struct GameHUD: View {
    let game: GameID
    let level: Int
    let model: any GameViewModel
    let clock: GameClock
    let onPause: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: onPause) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: Theme.minTouch, height: Theme.minTouch)
                        .background(Circle().fill(Theme.surface).shadow(color: Theme.ink.opacity(0.08), radius: 6, y: 2))
                }
                .accessibilityLabel(L("game.pause"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(game.name).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                    Text(L("game.levelN", String(level))).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                if let progress = model.hudProgress {
                    Chip(text: ltr(progress), symbol: "flag.fill", tint: game.color)
                        .accessibilityLabel(L("game.progress.a11y", progress))
                }
                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(model.hudScore))
                        .font(.fitnaNumber(24))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: model.hudScore)
                    Text(L("game.points")).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            if model.hudTimeFraction != nil {
                // Time-based values aren't observable, so redraw with the display refresh.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: clock.isPaused)) { _ in
                    let fraction = model.hudTimeFraction ?? 0
                    ProgressBar(fraction: fraction,
                                tint: fraction < 0.2 ? AnyShapeStyle(Theme.error) : AnyShapeStyle(game.color),
                                height: 8)
                        .accessibilityLabel(L("game.timeLeft"))
                        .accessibilityValue(NumberText.percent(fraction))
                }
            }
        }
        .padding(.horizontal, Theme.padding)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

// MARK: - Countdown

struct CountdownView: View {
    let value: Int
    let tint: Color
    @State private var pop = false

    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.12)).frame(width: 220, height: 220)
            Circle().stroke(tint.opacity(0.35), lineWidth: 6).frame(width: 180, height: 180)
            Text(String(value))
                .font(.system(size: 96, weight: .heavy, design: .rounded))
                .foregroundStyle(tint)
                .scaleEffect(pop ? 1 : 0.6)
                .opacity(pop ? 1 : 0.2)
        }
        .onAppear { animate() }
        .onChange(of: value) { _, _ in animate() }
        .accessibilityLabel(String(value))
    }

    private func animate() {
        pop = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { pop = true }
    }
}

// MARK: - Pause

struct PauseOverlay: View {
    let game: GameID
    let onResume: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                IconBadge(symbol: "pause.fill", tint: game.color, size: 60)
                Text(L("pause.title")).font(.fitnaTitle).foregroundStyle(Theme.ink)
                Text(game.hint)
                    .font(.fitnaCallout)
                    .foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                Button(L("pause.resume"), action: onResume).buttonStyle(PrimaryButtonStyle())
                Button(L("pause.restart"), action: onRestart).buttonStyle(SecondaryButtonStyle())
                Button(L("pause.exit"), role: .destructive, action: onExit)
                    .font(.fitnaHeadline)
                    .foregroundStyle(Theme.error)
                    .frame(minHeight: Theme.minTouch)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.surface))
            .padding(28)
        }
    }
}
