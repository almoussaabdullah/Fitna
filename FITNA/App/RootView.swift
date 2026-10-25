import SwiftUI
import SwiftData
import FitnaKit

struct RootView: View {
    @AppStorage(SettingsKey.onboardingDone) private var onboardingDone = false
    @State private var selectedTab: AppTab = .home
    @State private var startAssessmentAfterOnboarding = false

    var body: some View {
        Group {
            if onboardingDone {
                MainTabView(selection: $selectedTab, startAssessment: $startAssessmentAfterOnboarding)
            } else {
                OnboardingView { choice in
                    switch choice {
                    case .assessment:
                        selectedTab = .brainTest
                        startAssessmentAfterOnboarding = true
                    case .games:
                        selectedTab = .games
                    case .skip:
                        selectedTab = .home
                    }
                    withAnimation(.easeInOut(duration: 0.35)) { onboardingDone = true }
                }
                .transition(.opacity)
            }
        }
    }
}

enum AppTab: Hashable {
    case home, games, brainTest, progress, profile
}

struct MainTabView: View {
    @Binding var selection: AppTab
    @Binding var startAssessment: Bool

    var body: some View {
        TabView(selection: $selection) {
            HomeView(selectedTab: $selection)
                .tabItem { Label(L("tab.home"), systemImage: "house.fill") }
                .tag(AppTab.home)
            GamesView()
                .tabItem { Label(L("tab.games"), systemImage: "square.grid.2x2.fill") }
                .tag(AppTab.games)
            BrainTestView(autoStart: $startAssessment)
                .tabItem { Label(L("tab.brainTest"), systemImage: "brain.head.profile") }
                .tag(AppTab.brainTest)
            ProgressDashboardView()
                .tabItem { Label(L("tab.progress"), systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)
            ProfileView()
                .tabItem { Label(L("tab.profile"), systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
    }
}
