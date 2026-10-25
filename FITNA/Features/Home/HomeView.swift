import SwiftUI
import SwiftData
import FitnaKit

struct HomeView: View {
    @Binding var selectedTab: AppTab

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GameSession.endedAt) private var sessions: [GameSession]
    @Query private var profiles: [PlayerProfile]
    @Query(sort: \DailyWorkout.date, order: .reverse) private var workouts: [DailyWorkout]

    @State private var playing: GameID?
    @State private var showWorkout = false

    private var profile: PlayerProfile? { profiles.first }
    private var overview: PlayerOverview { PlayerOverview.make(sessions: sessions, totalXP: profile?.totalXP ?? 0) }
    private var todayWorkout: DailyWorkout? { workouts.first { $0.dayKey == DayKey.key(for: Date()) } }

    var body: some View {
        let ov = overview
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header(ov)
                    levelCard(ov)
                    workoutCard
                    scoreCard(ov)
                    dailyChallenge(ov)
                    recommended(ov)
                    recentPerformance(ov)
                }
                .padding(Theme.padding)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(item: $playing) { game in
            GameHostView(game: game, launch: .free) { playing = nil }
        }
        .fullScreenCover(isPresented: $showWorkout) {
            DailyWorkoutView { showWorkout = false }
        }
    }

    // MARK: Sections

    private func header(_ ov: PlayerOverview) -> some View {
        HStack(spacing: 14) {
            let avatar = AvatarOption.option(id: profile?.avatarID ?? "brain")
            AvatarView(symbol: avatar.symbol, tint: Theme.accent(avatar.paletteIndex), size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.fitnaCallout).foregroundStyle(Theme.inkSecondary)
                Text(displayName).font(.fitnaTitle).foregroundStyle(Theme.ink)
            }
            Spacer()
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ov.currentStreak > 0 ? Theme.orange : Theme.inkTertiary)
                Text(String(ov.currentStreak)).font(.fitnaNumber(17)).foregroundStyle(Theme.ink)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.orangeSoft))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L("home.a11y.streak", String(ov.currentStreak)))
        }
    }

    private var displayName: String {
        let name = profile?.nickname.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? L("home.defaultName") : name
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return L("home.greeting.morning")
        case 12..<18: return L("home.greeting.afternoon")
        default: return L("home.greeting.evening")
        }
    }

    private func levelCard(_ ov: PlayerOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("home.level", String(ov.levelInfo.level))).font(.fitnaHeadline).foregroundStyle(.white)
                    Text(L("home.xpTotal", String(ov.totalXP))).font(.fitnaCaption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Image(systemName: "star.circle.fill").font(.system(size: 30)).foregroundStyle(Theme.orange)
            }
            ProgressBar(fraction: ov.levelInfo.fraction, tint: AnyShapeStyle(Theme.orange), height: 10)
            Text(L("home.toNextLevel", String(ov.levelInfo.xpForNextLevel - ov.levelInfo.xpIntoLevel), String(ov.levelInfo.level + 1)))
                .font(.fitnaCaption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(Theme.padding)
        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.heroGradient))
        .shadow(color: Theme.purple.opacity(0.3), radius: 16, y: 8)
        .accessibilityElement(children: .combine)
    }

    private var workoutCard: some View {
        let done = todayWorkout?.isCompleted == true
        let progress = todayWorkout?.progressFraction ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconBadge(symbol: done ? "checkmark.seal.fill" : "figure.mind.and.body", tint: done ? Theme.success : Theme.turquoise, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("home.workout.title")).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                    Text(done ? L("home.workout.done") : L("home.workout.subtitle"))
                        .font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                if progress > 0 && !done {
                    ProgressRing(fraction: progress, lineWidth: 5, tint: Theme.turquoise)
                        .frame(width: 34, height: 34)
                }
            }
            Button { showWorkout = true } label: {
                Label(done ? L("home.workout.review") : (progress > 0 ? L("home.workout.continue") : L("home.workout.start")),
                      systemImage: done ? "list.bullet.clipboard" : "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(fill: AnyShapeStyle(done ? AnyShapeStyle(Theme.success) : AnyShapeStyle(Theme.turquoiseGradient))))
        }
        .fitnaCard()
    }

    private func scoreCard(_ ov: PlayerOverview) -> some View {
        HStack(spacing: 18) {
            ZStack {
                ProgressRing(fraction: (ov.statistics.overallScore ?? 0) / 100, lineWidth: 10, tint: Theme.purple)
                VStack(spacing: 0) {
                    Text(NumberText.score(ov.statistics.overallScore)).font(.fitnaNumber(28, weight: .heavy)).foregroundStyle(Theme.ink)
                    Text(L("home.outOf100")).font(.fitnaCaption).foregroundStyle(Theme.inkTertiary)
                }
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text(L("home.brainScore")).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                if let tier = ov.tier {
                    Chip(text: L(tier.nameKey), symbol: tier.symbol, tint: Theme.purple)
                    Text(L("home.tierNote")).font(.fitnaCaption).foregroundStyle(Theme.inkTertiary)
                } else {
                    Text(L("home.noScoreYet")).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .fitnaCard()
        .accessibilityElement(children: .combine)
    }

    private func dailyChallenge(_ ov: PlayerOverview) -> some View {
        let game = PlayerOverview.dailyChallenge()
        let best = ov.statistics.bestRawScore[game]
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: L("home.challenge.title"))
            Button { playing = game } label: {
                HStack(spacing: 14) {
                    IconBadge(symbol: game.symbol, tint: game.color, size: 54)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.name).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                        Text(best.map { L("home.challenge.beat", String($0)) } ?? L("home.challenge.first"))
                            .font(.fitnaCaption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.left").foregroundStyle(Theme.inkTertiary)
                }
                .fitnaCard(padding: 14)
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func recommended(_ ov: PlayerOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: L("home.recommended"), trailing: L("home.seeAll")) { selectedTab = .games }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ov.recommendations(count: 4)) { game in
                        Button { playing = game } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                IconBadge(symbol: game.symbol, tint: game.color, size: 46)
                                Text(game.name).font(.fitnaHeadline).foregroundStyle(Theme.ink).lineLimit(1)
                                Chip(text: game.skill.name, tint: game.color)
                            }
                            .frame(width: 150, alignment: .leading)
                            .fitnaCard(padding: 14)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
        }
    }

    private func recentPerformance(_ ov: PlayerOverview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: L("home.recent"))
            if ov.recent.isEmpty {
                EmptyStateView(symbol: "chart.bar.xaxis", title: L("home.recent.emptyTitle"), message: L("home.recent.emptyMessage"))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(ov.recent.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            Image(systemName: item.game.symbol)
                                .foregroundStyle(item.game.color)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.game.name).font(.fitnaBodyMedium).foregroundStyle(Theme.ink)
                                Text(item.date, format: .relative(presentation: .named))
                                    .font(.fitnaCaption).foregroundStyle(Theme.inkTertiary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(item.rawScore)).font(.fitnaNumber(17)).foregroundStyle(Theme.ink)
                                Text(NumberText.percent(item.accuracy)).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                            }
                        }
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
                        if index < ov.recent.count - 1 { Divider() }
                    }
                }
                .fitnaCard(padding: 14)
            }
        }
    }
}
