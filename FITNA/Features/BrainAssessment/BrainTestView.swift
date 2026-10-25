import SwiftUI
import SwiftData
import FitnaKit

/// اختبار العقل — tab root: explanation, latest result, history, start button.
struct BrainTestView: View {
    @Binding var autoStart: Bool
    @Query(sort: \BrainAssessment.date, order: .reverse) private var assessments: [BrainAssessment]
    @State private var running = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    intro
                    if let latest = assessments.first {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: L("bt2.latest"))
                            AssessmentReportCard(assessment: latest, previous: assessments.dropFirst().first)
                        }
                    }
                    if assessments.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: L("bt2.history"))
                            VStack(spacing: 0) {
                                ForEach(Array(assessments.prefix(10).enumerated()), id: \.element.id) { index, a in
                                    HStack {
                                        Text(a.date, format: .dateTime.day().month().year())
                                            .font(.fitnaBodyMedium).foregroundStyle(Theme.ink)
                                        Spacer()
                                        Text(NumberText.score(a.overallScore)).font(.fitnaNumber(18)).foregroundStyle(Theme.purple)
                                    }
                                    .padding(.vertical, 10)
                                    if index < min(10, assessments.count) - 1 { Divider() }
                                }
                            }
                            .fitnaCard(padding: 14)
                        }
                    }
                    Text(L("bt2.disclaimer"))
                        .font(.fitnaCaption)
                        .foregroundStyle(Theme.inkTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(Theme.padding)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("tab.brainTest"))
        }
        .fullScreenCover(isPresented: $running) {
            AssessmentFlowView { running = false }
        }
        .onAppear {
            if autoStart {
                autoStart = false
                running = true
            }
        }
        .onChange(of: autoStart) { _, start in
            if start {
                autoStart = false
                running = true
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconBadge(symbol: "brain.head.profile", tint: Theme.purple, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("bt2.title")).font(.fitnaTitle2).foregroundStyle(Theme.ink)
                    Text(L("bt2.subtitle")).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                }
            }
            HStack(spacing: 6) {
                ForEach(CognitiveSkill.allCases) { skill in
                    Image(systemName: skill.symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(skill.color)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(skill.color.opacity(0.12)))
                        .accessibilityLabel(skill.name)
                }
                Spacer()
                Chip(text: L("bt2.duration"), symbol: "clock.fill", tint: Theme.inkSecondary)
            }
            Button { running = true } label: {
                Label(assessments.isEmpty ? L("bt2.start") : L("bt2.retake"), systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .fitnaCard()
    }
}

/// Runs the five assessment challenges and saves the report.
struct AssessmentFlowView: View {
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var plan: [AssessmentPlanner.Item] = []
    @State private var index = 0
    @State private var results: [CognitiveSkill: (score: Double, game: GameID, level: Int)] = [:]
    @State private var saved: BrainAssessment?
    @State private var playing = false
    @State private var newAchievements: [AchievementID] = []

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if let saved {
                AssessmentResultView(assessment: saved, newAchievements: newAchievements, onClose: onClose)
            } else if playing, index < plan.count {
                let item = plan[index]
                GameHostView(game: item.game, launch: .assessment(level: item.level), onExit: onClose) { summary in
                    results[item.skill] = (summary.performance ?? 0, item.game, item.level)
                    advance()
                }
                .id(index)
            } else {
                between
            }
        }
        .onAppear {
            if plan.isEmpty {
                plan = AssessmentPlanner.plan(levels: Store.allLevels(in: modelContext), seed: UInt64.random(in: 0...UInt64.max))
            }
        }
    }

    private var between: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.inkSecondary)
                        .frame(width: Theme.minTouch, height: Theme.minTouch)
                }
                .accessibilityLabel(L("common.close"))
                Spacer()
            }
            Spacer()
            if index < plan.count {
                let item = plan[index]
                Text(L("bt2.step", String(index + 1), String(plan.count)))
                    .font(.fitnaCallout).foregroundStyle(Theme.inkSecondary)
                IconBadge(symbol: item.skill.symbol, tint: item.skill.color, size: 84)
                Text(item.skill.name).font(.fitnaDisplay).foregroundStyle(Theme.ink)
                Text(item.skill.detail).font(.fitnaBody).foregroundStyle(Theme.inkSecondary).multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    ForEach(0..<plan.count, id: \.self) { i in
                        Capsule().fill(i < index ? Theme.success : (i == index ? item.skill.color : Theme.hairline))
                            .frame(width: 28, height: 6)
                    }
                }
            }
            Spacer()
            Button { playing = true } label: { Label(L("bt2.go"), systemImage: "play.fill") }
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(Theme.padding)
    }

    private func advance() {
        playing = false
        index += 1
        if index >= plan.count { save() }
    }

    private func save() {
        let perf = results.mapValues { $0.score }
        let overall = AssessmentPlanner.overall(perf)
        let a = BrainAssessment(date: Date(), overallScore: overall)
        modelContext.insert(a)
        for skill in CognitiveSkill.allCases {
            let r = results[skill]
            let s = CognitiveSkillScore(skillRaw: skill.rawValue, score: r?.score ?? 0, gameRaw: r?.game.rawValue ?? "", level: r?.level ?? 1)
            modelContext.insert(s)
            s.assessment = a
        }
        try? modelContext.save()
        newAchievements = GameRecorder.awardBonus(xp: Progression.assessmentBonusXP, in: modelContext)
        Feedback.success()
        saved = a
    }
}

struct AssessmentResultView: View {
    let assessment: BrainAssessment
    let newAchievements: [AchievementID]
    let onClose: () -> Void
    @Query(sort: \BrainAssessment.date, order: .reverse) private var all: [BrainAssessment]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        ConfettiView().frame(height: 120)
                        Text(L("bt2.resultTitle")).font(.fitnaTitle).foregroundStyle(Theme.ink)
                    }
                    AssessmentReportCard(assessment: assessment, previous: all.first { $0.id != assessment.id && $0.date < assessment.date })
                    ForEach(newAchievements, id: \.self) { ach in
                        Label(L("results.achievement", L(ach.titleKey)), systemImage: ach.symbol)
                            .font(.fitnaHeadline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(RoundedRectangle(cornerRadius: Theme.corner).fill(Theme.purple.gradient))
                    }
                    Text(L("bt2.disclaimer")).font(.fitnaCaption).foregroundStyle(Theme.inkTertiary).multilineTextAlignment(.center)
                }
                .padding(Theme.padding)
            }
            Button(L("results.done"), action: onClose).buttonStyle(PrimaryButtonStyle()).padding(Theme.padding)
        }
    }
}

/// Radar chart + overall score + per-category bars.
struct AssessmentReportCard: View {
    let assessment: BrainAssessment
    let previous: BrainAssessment?

    var body: some View {
        let scores = assessment.scoresBySkill
        let tier = BrainTier.tier(forScore: assessment.overallScore)
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("bt2.overall")).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(NumberText.score(assessment.overallScore)).font(.fitnaNumber(44, weight: .heavy)).foregroundStyle(Theme.ink)
                        Text(L("home.outOf100")).font(.fitnaCaption).foregroundStyle(Theme.inkTertiary)
                    }
                    if let prev = previous {
                        let diff = assessment.overallScore - prev.overallScore
                        Chip(text: L(diff >= 0 ? "bt2.up" : "bt2.down", NumberText.score(abs(diff))),
                             symbol: diff >= 0 ? "arrow.up.right" : "arrow.down.right",
                             tint: diff >= 0 ? Theme.success : Theme.orange)
                    }
                    Chip(text: L(tier.nameKey), symbol: tier.symbol, tint: Theme.purple)
                }
                Spacer()
            }
            RadarChart(values: CognitiveSkill.allCases.map { (scores[$0] ?? 0) / 100 },
                       previous: previous.map { p in CognitiveSkill.allCases.map { (p.scoresBySkill[$0] ?? 0) / 100 } },
                       labels: CognitiveSkill.allCases.map(\.name),
                       symbols: CognitiveSkill.allCases.map(\.symbol))
                .frame(height: 260)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(CognitiveSkill.allCases.map { "\($0.name) \(NumberText.score(scores[$0]))" }.joined(separator: "، "))
            VStack(spacing: 10) {
                ForEach(CognitiveSkill.allCases) { skill in
                    HStack(spacing: 10) {
                        Image(systemName: skill.symbol).foregroundStyle(skill.color).frame(width: 24)
                        Text(skill.name).font(.fitnaCallout).foregroundStyle(Theme.ink).frame(width: 90, alignment: .leading)
                        ProgressBar(fraction: (scores[skill] ?? 0) / 100, tint: AnyShapeStyle(skill.color), height: 8)
                        Text(NumberText.score(scores[skill])).font(.fitnaNumber(15)).foregroundStyle(Theme.ink).frame(width: 32)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Text(L("bt2.howScored")).font(.fitnaCaption).foregroundStyle(Theme.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fitnaCard()
    }
}

/// Pentagon radar chart drawn with Shapes (Swift Charts has no radar type).
struct RadarChart: View {
    let values: [Double]          // 0…1, one per axis
    var previous: [Double]? = nil
    let labels: [String]
    let symbols: [String]

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let radius = size * 0.34
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    RadarPolygon(values: Array(repeating: Double(ring) / 4, count: values.count), center: center, radius: radius)
                        .stroke(Theme.hairline, lineWidth: 1)
                }
                ForEach(0..<values.count, id: \.self) { i in
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: RadarPolygon.point(i, of: values.count, value: 1, center: center, radius: radius))
                    }
                    .stroke(Theme.hairline, lineWidth: 1)
                }
                if let previous {
                    RadarPolygon(values: previous, center: center, radius: radius)
                        .stroke(Theme.inkTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                RadarPolygon(values: values, center: center, radius: radius)
                    .fill(Theme.purple.opacity(0.22))
                RadarPolygon(values: values, center: center, radius: radius)
                    .stroke(Theme.purple, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                ForEach(0..<values.count, id: \.self) { i in
                    Circle().fill(Theme.purple)
                        .frame(width: 7, height: 7)
                        .position(RadarPolygon.point(i, of: values.count, value: values[i], center: center, radius: radius))
                    VStack(spacing: 2) {
                        Image(systemName: symbols[i]).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.inkSecondary)
                        Text(labels[i]).font(.fitnaCaptionBold).foregroundStyle(Theme.ink)
                    }
                    .position(RadarPolygon.point(i, of: values.count, value: 1.32, center: center, radius: radius))
                }
            }
        }
    }
}

struct RadarPolygon: Shape {
    let values: [Double]
    let center: CGPoint
    let radius: CGFloat

    static func point(_ i: Int, of n: Int, value: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = -Double.pi / 2 + Double(i) * 2 * .pi / Double(max(n, 1))
        let r = radius * CGFloat(max(0, value))
        return CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard !values.isEmpty else { return p }
        for (i, v) in values.enumerated() {
            let pt = RadarPolygon.point(i, of: values.count, value: max(0.02, v), center: center, radius: radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
