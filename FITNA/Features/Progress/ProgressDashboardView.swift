import SwiftUI
import SwiftData
import Charts
import FitnaKit

/// تطوري — dashboard built only from real stored sessions.
struct ProgressDashboardView: View {
    @Query(sort: \GameSession.endedAt) private var sessions: [GameSession]

    enum Range: String, CaseIterable, Identifiable {
        case week, month, all
        var id: String { rawValue }
        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }

    @State private var range: Range = .week

    var body: some View {
        let data = ProgressData(sessions: sessions, range: range)
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker(L("progress.range"), selection: $range) {
                        ForEach(Range.allCases) { r in Text(L("progress.range.\(r.rawValue)")).tag(r) }
                    }
                    .pickerStyle(.segmented)

                    if data.completedCount == 0 {
                        EmptyStateView(symbol: "chart.line.uptrend.xyaxis", title: L("progress.empty.title"), message: L("progress.empty.message"))
                    } else {
                        summaryTiles(data)
                        improvementCard(data)
                        overallChart(data)
                        activityChart(data)
                        categoryChart(data)
                        periodChart(data)
                        recordsCard(data)
                    }
                }
                .padding(Theme.padding)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("tab.progress"))
        }
    }

    // MARK: Sections

    private func summaryTiles(_ d: ProgressData) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(symbol: "gauge.with.dots.needle.67percent", value: NumberText.score(d.overallNow), label: L("progress.overall"), tint: Theme.purple)
            StatTile(symbol: "checkmark.circle.fill", value: String(d.completedCount), label: L("progress.completed"), tint: Theme.success)
            StatTile(symbol: "clock.fill", value: NumberText.duration(d.totalPlayTime), label: L("progress.playtime"), tint: Theme.turquoise)
            StatTile(symbol: "flame.fill", value: String(d.longestStreak), label: L("progress.longestStreak"), tint: Theme.orange)
        }
    }

    private func improvementCard(_ d: ProgressData) -> some View {
        HStack(spacing: 14) {
            let delta = d.improvement
            Image(systemName: delta == nil ? "minus" : (delta! >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(delta == nil ? Theme.inkTertiary : (delta! >= 0 ? Theme.success : Theme.orange))
            VStack(alignment: .leading, spacing: 4) {
                Text(L("progress.improvement")).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                if let delta {
                    Text(L(delta >= 0 ? "progress.improvement.up" : "progress.improvement.down", NumberText.score(abs(delta))))
                        .font(.fitnaCallout).foregroundStyle(Theme.inkSecondary)
                } else {
                    Text(L("progress.improvement.needMore")).font(.fitnaCallout).foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer()
        }
        .fitnaCard()
        .accessibilityElement(children: .combine)
    }

    private func overallChart(_ d: ProgressData) -> some View {
        chartCard(title: L("progress.chart.overall"), subtitle: L("progress.chart.overall.sub")) {
            Chart(d.overallHistory) { point in
                LineMark(x: .value(L("progress.axis.day"), point.date, unit: .day), y: .value(L("progress.axis.score"), point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.purple)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                AreaMark(x: .value(L("progress.axis.day"), point.date, unit: .day), y: .value(L("progress.axis.score"), point.value))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [Theme.purple.opacity(0.25), Theme.purple.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                PointMark(x: .value(L("progress.axis.day"), point.date, unit: .day), y: .value(L("progress.axis.score"), point.value))
                    .foregroundStyle(Theme.purple)
                    .symbolSize(30)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 190)
        }
    }

    private func activityChart(_ d: ProgressData) -> some View {
        chartCard(title: L("progress.chart.activity"), subtitle: L("progress.chart.activity.sub")) {
            Chart(d.dailyActivity) { point in
                BarMark(x: .value(L("progress.axis.day"), point.date, unit: .day), y: .value(L("progress.axis.sessions"), point.value))
                    .foregroundStyle(Theme.turquoise.gradient)
                    .cornerRadius(5)
            }
            .frame(height: 160)
        }
    }

    private func categoryChart(_ d: ProgressData) -> some View {
        chartCard(title: L("progress.chart.categories"), subtitle: L("progress.chart.categories.sub")) {
            VStack(spacing: 12) {
                Chart(d.categoryNow) { item in
                    BarMark(x: .value(L("progress.axis.score"), item.value), y: .value(L("progress.axis.skill"), item.skill.name))
                        .foregroundStyle(item.skill.color.gradient)
                        .cornerRadius(6)
                        .annotation(position: .trailing) {
                            Text(NumberText.score(item.value)).font(.fitnaCaptionBold).foregroundStyle(Theme.inkSecondary)
                        }
                }
                .chartXScale(domain: 0...100)
                .frame(height: CGFloat(max(1, d.categoryNow.count)) * 40 + 20)
            }
        }
    }

    private func periodChart(_ d: ProgressData) -> some View {
        chartCard(title: L("progress.chart.period.\(range.rawValue)"),
                  subtitle: L("progress.chart.period.sub")) {
            Chart(d.periodPerformance) { point in
                BarMark(x: .value(L("progress.axis.period"), point.label), y: .value(L("progress.axis.score"), point.value))
                    .foregroundStyle(Theme.orange.gradient)
                    .cornerRadius(5)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 170)
        }
    }

    private func recordsCard(_ d: ProgressData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: L("progress.records"))
            VStack(spacing: 0) {
                ForEach(Array(d.records.enumerated()), id: \.element.game) { index, rec in
                    HStack(spacing: 12) {
                        Image(systemName: rec.game.symbol).foregroundStyle(rec.game.color).frame(width: 28)
                        Text(rec.game.name).font(.fitnaBodyMedium).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(String(rec.best)).font(.fitnaNumber(17)).foregroundStyle(Theme.ink)
                        Image(systemName: "trophy.fill").font(.system(size: 12)).foregroundStyle(Theme.orange)
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if index < d.records.count - 1 { Divider() }
                }
            }
            .fitnaCard(padding: 14)
        }
    }

    private func chartCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.fitnaHeadline).foregroundStyle(Theme.ink)
            Text(subtitle).font(.fitnaCaption).foregroundStyle(Theme.inkTertiary)
            content()
                .environment(\.layoutDirection, .leftToRight) // time axes read left → right
        }
        .fitnaCard()
    }
}

/// Aggregations for the dashboard (pure computation over stored sessions).
struct ProgressData {
    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    struct LabeledPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    struct Record { let game: GameID; let best: Int }

    let completedCount: Int
    let totalPlayTime: Double
    let longestStreak: Int
    let overallNow: Double?
    let overallHistory: [Point]
    let dailyActivity: [Point]
    struct CategoryValue: Identifiable { let skill: CognitiveSkill; let value: Double; var id: String { skill.rawValue } }
    let categoryNow: [CategoryValue]
    let periodPerformance: [LabeledPoint]
    let records: [Record]
    /// Mean performance of the recent half of the range minus the earlier half.
    let improvement: Double?

    init(sessions: [GameSession], range: ProgressDashboardView.Range, now: Date = Date(), calendar: Calendar = .current) {
        let all = sessions.compactMap(\.summary)
        let start: Date? = range.days.map { calendar.date(byAdding: .day, value: -($0 - 1), to: calendar.startOfDay(for: now))! }
        let inRange = all.filter { start == nil || $0.date >= start! }
        let completedInRange = inRange.filter(\.completed)

        completedCount = completedInRange.count
        totalPlayTime = inRange.reduce(0) { $0 + $1.duration }
        let statsAll = PlayerStatistics.compute(from: all, calendar: calendar)
        longestStreak = Streaks.longest(activeDays: statsAll.activeDays, calendar: calendar)
        overallNow = statsAll.overallScore

        // Overall score as it stood at the end of each active day in range.
        let activeDays = Set(completedInRange.map { calendar.startOfDay(for: $0.date) }).sorted()
        overallHistory = activeDays.compactMap { day in
            let end = calendar.date(byAdding: .day, value: 1, to: day)!
            let upTo = all.filter { $0.date < end }
            guard let score = PlayerStatistics.compute(from: upTo, calendar: calendar).overallScore else { return nil }
            return Point(date: day, value: score)
        }

        // Sessions per day (range, or last 30 active days for "all").
        let firstDay = start ?? (completedInRange.first.map { calendar.startOfDay(for: $0.date) } ?? calendar.startOfDay(for: now))
        var counts: [Date: Int] = [:]
        for s in completedInRange { counts[calendar.startOfDay(for: s.date), default: 0] += 1 }
        var days: [Point] = []
        var d = firstDay
        let today = calendar.startOfDay(for: now)
        while d <= today && days.count < 120 {
            days.append(Point(date: d, value: Double(counts[d] ?? 0)))
            d = calendar.date(byAdding: .day, value: 1, to: d)!
        }
        dailyActivity = range == .all ? Array(days.suffix(30)) : days

        categoryNow = CognitiveSkill.allCases.compactMap { skill in
            let perf = completedInRange.filter { $0.gameID.skill == skill }.sorted { $0.date > $1.date }.compactMap(\.performance)
            return ScoringModel.categoryScore(recentPerformancesNewestFirst: perf).map { CategoryValue(skill: skill, value: $0) }
        }

        // Weekly buckets for week/month ranges, monthly buckets for all-time.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar@numbers=latn")
        var buckets: [(Date, [Double])] = []
        if range == .all {
            formatter.setLocalizedDateFormatFromTemplate("MMM")
            let grouped = Dictionary(grouping: completedInRange) { calendar.dateInterval(of: .month, for: $0.date)!.start }
            buckets = grouped.map { ($0.key, $0.value.compactMap(\.performance)) }
        } else if range == .month {
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
            let grouped = Dictionary(grouping: completedInRange) { calendar.dateInterval(of: .weekOfYear, for: $0.date)!.start }
            buckets = grouped.map { ($0.key, $0.value.compactMap(\.performance)) }
        } else {
            formatter.setLocalizedDateFormatFromTemplate("EEE")
            let grouped = Dictionary(grouping: completedInRange) { calendar.startOfDay(for: $0.date) }
            buckets = grouped.map { ($0.key, $0.value.compactMap(\.performance)) }
        }
        periodPerformance = buckets.sorted { $0.0 < $1.0 }.compactMap { date, values in
            guard !values.isEmpty else { return nil }
            return LabeledPoint(label: formatter.string(from: date), value: values.reduce(0, +) / Double(values.count))
        }

        records = GameID.allCases.compactMap { g in statsAll.bestRawScore[g].map { Record(game: g, best: $0) } }

        let perfSorted = completedInRange.sorted { $0.date < $1.date }.compactMap(\.performance)
        if perfSorted.count >= 4 {
            let half = perfSorted.count / 2
            let early = perfSorted.prefix(half), late = perfSorted.suffix(perfSorted.count - half)
            improvement = late.reduce(0, +) / Double(late.count) - early.reduce(0, +) / Double(early.count)
        } else {
            improvement = nil
        }
    }
}
