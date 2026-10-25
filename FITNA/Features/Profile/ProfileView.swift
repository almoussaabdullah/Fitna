import SwiftUI
import SwiftData
import FitnaKit

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [PlayerProfile]
    @Query(sort: \GameSession.endedAt) private var sessions: [GameSession]
    @Query(sort: \Achievement.unlockedAt, order: .reverse) private var unlocked: [Achievement]

    @AppStorage(SettingsKey.sound) private var soundOn = true
    @AppStorage(SettingsKey.haptics) private var hapticsOn = true
    @AppStorage(SettingsKey.showTutorials) private var alwaysTutorials = false
    @AppStorage(SettingsKey.onboardingDone) private var onboardingDone = true
    @AppStorage("seenTutorials") private var seenTutorialsRaw = ""

    @State private var nickname = ""
    @State private var showReset = false
    @State private var showAvatarPicker = false

    private var profile: PlayerProfile? { profiles.first }

    var body: some View {
        let ov = PlayerOverview.make(sessions: sessions, totalXP: profile?.totalXP ?? 0)
        let unlockedIDs = Set(unlocked.compactMap { AchievementID(rawValue: $0.idRaw) })
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Button { showAvatarPicker = true } label: {
                            let avatar = AvatarOption.option(id: profile?.avatarID ?? "brain")
                            AvatarView(symbol: avatar.symbol, tint: Theme.accent(avatar.paletteIndex), size: 72)
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "pencil.circle.fill").font(.system(size: 22)).foregroundStyle(Theme.purple)
                                        .background(Circle().fill(.white))
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("profile.changeAvatar"))
                        VStack(alignment: .leading, spacing: 6) {
                            TextField(L("profile.nicknamePlaceholder"), text: $nickname)
                                .font(.fitnaTitle2)
                                .submitLabel(.done)
                                .onSubmit(saveNickname)
                            Text(L("home.level", String(ov.levelInfo.level)) + " · " + L("home.xpTotal", String(ov.totalXP)))
                                .font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                            ProgressBar(fraction: ov.levelInfo.fraction, height: 6)
                        }
                    }
                    .padding(.vertical, 6)
                    HStack {
                        Label(L("profile.streak"), systemImage: "flame.fill").foregroundStyle(Theme.ink)
                        Spacer()
                        Text(L("profile.days", String(ov.currentStreak))).foregroundStyle(Theme.inkSecondary)
                    }
                    .font(.fitnaBody)
                    HStack {
                        Label(L("profile.bestStreak"), systemImage: "medal.fill").foregroundStyle(Theme.ink)
                        Spacer()
                        Text(L("profile.days", String(ov.longestStreak))).foregroundStyle(Theme.inkSecondary)
                    }
                    .font(.fitnaBody)
                }

                Section {
                    NavigationLink {
                        AchievementsView(unlocked: unlocked)
                    } label: {
                        HStack {
                            Label(L("profile.achievements"), systemImage: "trophy.fill")
                            Spacer()
                            Text("\(unlockedIDs.count) / \(AchievementID.allCases.count)").font(.fitnaNumber(15)).foregroundStyle(Theme.inkSecondary)
                        }
                        .font(.fitnaBody)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(AchievementID.allCases) { ach in
                                let isOn = unlockedIDs.contains(ach)
                                Image(systemName: isOn ? ach.symbol : "lock.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(isOn ? .white : Theme.inkTertiary)
                                    .frame(width: 44, height: 44)
                                    .background(Circle().fill(isOn ? AnyShapeStyle(Theme.heroGradient) : AnyShapeStyle(Theme.hairline)))
                                    .accessibilityLabel(L(ach.titleKey))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(L("profile.settings")) {
                    Toggle(isOn: $soundOn) { Label(L("profile.sound"), systemImage: "speaker.wave.2.fill") }
                    Toggle(isOn: $hapticsOn) { Label(L("profile.haptics"), systemImage: "iphone.radiowaves.left.and.right") }
                    Toggle(isOn: $alwaysTutorials) { Label(L("profile.tutorials"), systemImage: "lightbulb.fill") }
                    Button {
                        onboardingDone = false
                    } label: {
                        Label(L("profile.replayOnboarding"), systemImage: "sparkles")
                    }
                }
                .font(.fitnaBody)

                Section(L("profile.about")) {
                    NavigationLink {
                        InfoPage(title: L("profile.scoring"), body: L("info.scoring"))
                    } label: { Label(L("profile.scoring"), systemImage: "function") }
                    NavigationLink {
                        InfoPage(title: L("profile.privacy"), body: L("info.privacy"))
                    } label: { Label(L("profile.privacy"), systemImage: "hand.raised.fill") }
                    NavigationLink {
                        InfoPage(title: L("profile.credits"), body: L("info.credits"))
                    } label: { Label(L("profile.credits"), systemImage: "info.circle.fill") }
                }
                .font(.fitnaBody)

                Section {
                    Button(role: .destructive) { showReset = true } label: {
                        Label(L("profile.reset"), systemImage: "arrow.counterclockwise")
                    }
                    .font(.fitnaBody)
                } footer: {
                    Text(L("profile.resetFooter")).font(.fitnaCaption)
                }

                Section {
                    Text(L("profile.version", appVersion))
                        .font(.fitnaCaption)
                        .foregroundStyle(Theme.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L("tab.profile"))
            .onAppear { nickname = profile?.nickname ?? "" }
            .onChange(of: nickname) { _, _ in saveNickname() }
            .confirmationDialog(L("profile.reset.confirmTitle"), isPresented: $showReset, titleVisibility: .visible) {
                Button(L("profile.reset.confirm"), role: .destructive, action: resetProgress)
                Button(L("common.cancel"), role: .cancel) {}
            } message: {
                Text(L("profile.reset.message"))
            }
            .sheet(isPresented: $showAvatarPicker) {
                AvatarPicker(level: ov.levelInfo.level, selected: profile?.avatarID ?? "brain") { id in
                    Store.profile(in: modelContext).avatarID = id
                    try? modelContext.save()
                    showAvatarPicker = false
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func saveNickname() {
        let trimmed = String(nickname.prefix(24))
        let p = Store.profile(in: modelContext)
        if p.nickname != trimmed {
            p.nickname = trimmed
            try? modelContext.save()
        }
    }

    private func resetProgress() {
        Store.resetAll(in: modelContext)
        seenTutorialsRaw = ""
        nickname = ""
        Feedback.tap()
    }
}

struct AvatarPicker: View {
    let level: Int
    let selected: String
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("profile.pickAvatar")).font(.fitnaTitle2).foregroundStyle(Theme.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                ForEach(AvatarOption.all) { opt in
                    let locked = opt.unlockLevel > level
                    Button { if !locked { onPick(opt.id) } } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                AvatarView(symbol: opt.symbol, tint: locked ? Theme.inkTertiary : Theme.accent(opt.paletteIndex), size: 60)
                                if locked {
                                    Image(systemName: "lock.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.inkSecondary)
                                        .offset(x: 22, y: 22)
                                }
                            }
                            .overlay(Circle().stroke(opt.id == selected ? Theme.purple : .clear, lineWidth: 3))
                            Text(locked ? L("profile.unlockAt", String(opt.unlockLevel)) : " ")
                                .font(.fitnaCaption).foregroundStyle(Theme.inkTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(locked)
                    .accessibilityLabel(locked ? L("profile.unlockAt", String(opt.unlockLevel)) : L("profile.avatarOption"))
                }
            }
            Spacer()
        }
        .padding(Theme.padding)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct AchievementsView: View {
    let unlocked: [Achievement]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let ctx = GameRecorder.achievementContext(in: modelContext)
        let dates = Dictionary(uniqueKeysWithValues: unlocked.compactMap { a in AchievementID(rawValue: a.idRaw).map { ($0, a.unlockedAt) } })
        ScrollView {
            VStack(spacing: 12) {
                ForEach(AchievementID.allCases) { ach in
                    let p = ach.progress(in: ctx)
                    let date = dates[ach]
                    HStack(spacing: 14) {
                        Image(systemName: date != nil ? ach.symbol : "lock.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(date != nil ? .white : Theme.inkTertiary)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(date != nil ? AnyShapeStyle(Theme.heroGradient) : AnyShapeStyle(Theme.hairline)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L(ach.titleKey)).font(.fitnaHeadline).foregroundStyle(Theme.ink)
                            Text(L(ach.detailKey)).font(.fitnaCaption).foregroundStyle(Theme.inkSecondary)
                            if let date {
                                Text(date, format: .dateTime.day().month().year()).font(.fitnaCaption).foregroundStyle(Theme.success)
                            } else {
                                HStack(spacing: 8) {
                                    ProgressBar(fraction: Double(min(p.current, p.target)) / Double(p.target), height: 6)
                                    Text("\(min(p.current, p.target))/\(p.target)").font(.fitnaNumber(12, weight: .semibold))
                                        .foregroundStyle(Theme.inkSecondary)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .fitnaCard(padding: 14)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(Theme.padding)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L("profile.achievements"))
    }
}

struct InfoPage: View {
    let title: String
    let body_: String

    init(title: String, body: String) {
        self.title = title
        self.body_ = body
    }

    var body: some View {
        ScrollView {
            Text(body_)
                .font(.fitnaBody)
                .foregroundStyle(Theme.ink)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fitnaCard()
                .padding(Theme.padding)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
    }
}
