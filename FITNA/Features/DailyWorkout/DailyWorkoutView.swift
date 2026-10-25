import SwiftUI
import SwiftData
import FitnaKit

/// تمرين اليوم — five short challenges, one per skill, then a summary.
struct DailyWorkoutView: View {
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var workout: DailyWorkout?
    @State private var playing: GameID?
    @State private var bonusAchievements: [AchievementID] = []
    @State private var justFinished = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let game = playing {
                GameHostView(game: game, launch: .workout, onExit: { playing = nil }) { summary in
                    handle(summary, for: game)
                }
                .transition(.opacity)
            } else if let w = workout {
                if w.isCompleted {
                    WorkoutSummaryView(workout: w, newAchievements: bonusAchievements, celebrate: justFinished, onClose: onClose)
                } else {
                    overview(w)
                }
            } else {
                ProgressView().tint(Theme.purple)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: playing)
        .onAppear(perform: loadOrCreate)
    }

    // MARK: Overview

    private func overview(_ w: DailyWorkout) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.inkSecondary)
                        .frame(width: Theme.minTouch, height: Theme.minTouch)
                }
                .accessibilityLabel(L("common.close"))
                Spacer()
            }
            .padding(.horizontal, 12)

            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        IconBadge(symbol: "figure.mind.and.body", tint: Theme.turquoise, size: 72)
                        Text(L("workout.title")).font(.fitnaDisplay).foregroundStyle(Theme.ink)
                        Text(L("workout.subtitle")).font(.fitnaCallout).foregroundStyle(Theme.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    ProgressBar(fraction: w.progressFraction, tint: AnyShapeStyle(Theme.turquoiseGradient), height: 10)
                        .accessibilityLabel(L("workout.a11y.progress", String(w.completedGamesRaw.count), String(w.games.count)))

                    VStack(spacing: 10) {
                        ForEach(Array(w.games.enumerated()), id: \.offset) { index, game in
                            let done = w.completedGamesRaw.contains(game.rawValue)
                            let isNext = w.nextGame == game
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle().fill(done ? Theme.success : (isNext ? game.color : Theme.hairline))
                                    if done {
                                        Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                                    } else {
                                        Text(String(index + 1)).font(.fitnaNumber(15)).foregroundStyle(isNext ? .white : Theme.inkSecondary)
                                    }
                                }
                                .frame(width: 34, height: 34)
                                IconBadge(symbol: game.symbol, tint: game.color, size: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.name).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                                    Text(game.skill.name).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                                }
                                Spacer()
                                if done, let i = w.completedGamesRaw.firstIndex(of: game.rawValue), i < w.performances.count {
                                    Text(NumberText.score(w.performances[i])).font(.fitnaNumber(17)).foregroundStyle(Theme.success)
                                }
                            }
                            .fitnaCard(padding: 12)
                            .opacity(done ? 0.8 : 1)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(Theme.padding)
            }

            if let next = w.nextGame {
                Button { playing = next } label: {
                    Label(w.completedGamesRaw.isEmpty ? L("workout.start") : L("workout.next", next.name), systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle(fill: AnyShapeStyle(Theme.turquoiseGradient)))
                .padding(Theme.padding)
            }
        }
    }

    // MARK: Data

    private func loadOrCreate() {
        let now = Date()
        let key = DayKey.key(for: now)
        if let existing = Store.workout(dayKey: key, in: modelContext) {
            workout = existing
            return
        }
        let overview = PlayerOverview.make(sessions: Store.sessions(in: modelContext), totalXP: Store.profile(in: modelContext).totalXP, now: now)
        let yesterdayKey = DayKey.key(for: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now)
        let previous = Store.workout(dayKey: yesterdayKey, in: modelContext)?.games ?? []
        let plan = DailyWorkoutPlanner.plan(for: now, categoryScores: overview.statistics.categoryScores,
                                            lastPlayed: overview.lastPlayed, previousWorkoutGames: previous)
        let w = DailyWorkout(dayKey: key, date: now, gamesRaw: plan.map(\.rawValue))
        modelContext.insert(w)
        try? modelContext.save()
        workout = w
    }

    private func handle(_ summary: RecordSummary, for game: GameID) {
        guard let w = workout else { return }
        if !w.completedGamesRaw.contains(game.rawValue) {
            w.completedGamesRaw.append(game.rawValue)
            w.performances.append(summary.performance ?? 0)
            w.totalPoints += summary.outcome.rawScore
            w.correct += summary.outcome.correct
            w.attempts += summary.outcome.attempts
            w.xpEarned += summary.xpEarned
        }
        if w.nextGame == nil && !w.isCompleted {
            w.isCompleted = true
            w.completedAt = Date()
            w.xpEarned += Progression.workoutBonusXP
            try? modelContext.save()
            bonusAchievements = summary.newAchievements + GameRecorder.awardBonus(xp: Progression.workoutBonusXP, in: modelContext)
            justFinished = true
        } else {
            try? modelContext.save()
        }
        playing = nil
    }
}

struct WorkoutSummaryView: View {
    let workout: DailyWorkout
    let newAchievements: [AchievementID]
    let celebrate: Bool
    let onClose: () -> Void
    @State private var appeared = false

    private var performances: [CognitiveSkill: Double] {
        var map: [CognitiveSkill: Double] = [:]
        for (i, raw) in workout.completedGamesRaw.enumerated() {
            if let g = GameID(rawValue: raw), i < workout.performances.count { map[g.skill] = workout.performances[i] }
        }
        return map
    }

    var body: some View {
        let perf = performances
        let accuracy = workout.attempts == 0 ? 0 : Double(workout.correct) / Double(workout.attempts)
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        if celebrate { ConfettiView().frame(height: 160) }
                        IconBadge(symbol: "checkmark.seal.fill", tint: Theme.success, size: 90)
                            .scaleEffect(appeared ? 1 : 0.5)
                    }
                    .frame(height: 160)
                    Text(L("workout.done.title")).font(.fitnaTitle).foregroundStyle(Theme.ink).multilineTextAlignment(.center)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        StatTile(symbol: "star.fill", value: String(workout.totalPoints), label: L("workout.done.points"), tint: Theme.purple)
                        StatTile(symbol: "target", value: NumberText.percent(accuracy), label: L("results.accuracy"), tint: Theme.turquoise)
                        StatTile(symbol: "sparkles", value: "+\(workout.xpEarned)", label: L("results.xp"), tint: Theme.orange)
                        StatTile(symbol: "flame.fill", value: L("workout.done.games", String(workout.completedGamesRaw.count)), label: L("workout.done.completed"), tint: Theme.error)
                    }

                    if let strong = WorkoutSummary.strongest(perf) {
                        insight(symbol: "arrow.up.circle.fill", title: L("workout.done.strongest"), skill: strong, tint: Theme.success)
                    }
                    if let weak = WorkoutSummary.weakest(perf), weak != WorkoutSummary.strongest(perf) {
                        insight(symbol: "target", title: L("workout.done.practice"), skill: weak, tint: Theme.orange)
                    }
                    ForEach(newAchievements, id: \.self) { ach in
                        HStack(spacing: 12) {
                            Image(systemName: ach.symbol).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                            Text(L("results.achievement", L(ach.titleKey))).font(.fitnaHeadline).foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: Theme.corner).fill(Theme.purple.gradient))
                    }
                    Text(L("workout.done.comeBack")).font(.fitnaCallout).foregroundStyle(Theme.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Theme.padding)
            }
            Button(L("results.done"), action: onClose)
                .buttonStyle(PrimaryButtonStyle())
                .padding(Theme.padding)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { appeared = true } }
    }

    private func insight(symbol: String, title: String, skill: CognitiveSkill, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 22, weight: .bold)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                Text(skill.name).font(.fitnaHeadline).foregroundStyle(Theme.ink)
            }
            Spacer()
            IconBadge(symbol: skill.symbol, tint: skill.color, size: 38)
        }
        .fitnaCard(padding: 14)
        .accessibilityElement(children: .combine)
    }
}

/// Lightweight confetti burst (respects Reduce Motion by not animating).
struct ConfettiView: View {
    @State private var fall = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let pieces: [(x: Double, delay: Double, color: Color, size: Double, spin: Double)] = (0..<28).map { i in
        let colors = [Theme.purple, Theme.turquoise, Theme.orange, Theme.error, Theme.success]
        return (x: Double((i * 37) % 100) / 100, delay: Double(i % 7) * 0.05, color: colors[i % colors.count],
                size: Double(6 + (i % 4) * 2), spin: Double((i * 53) % 360))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<pieces.count, id: \.self) { i in
                    let p = pieces[i]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 1.6)
                        .rotationEffect(.degrees(fall ? p.spin + 360 : p.spin))
                        .position(x: geo.size.width * p.x, y: fall ? geo.size.height + 20 : -20)
                        .opacity(fall ? 0 : 1)
                        .animation(.easeIn(duration: 1.6).delay(p.delay), value: fall)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { if !reduceMotion { fall = true } }
    }
}
