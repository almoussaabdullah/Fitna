import SwiftUI
import SwiftData

@main
struct FitnaApp: App {
    let container = PersistenceController.makeContainer(inMemory: ProcessInfo.processInfo.arguments.contains("-uiTesting"))

    init() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.sound: true,
            SettingsKey.haptics: true,
            SettingsKey.onboardingDone: false,
            SettingsKey.showTutorials: false
        ])
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            UserDefaults.standard.set(ProcessInfo.processInfo.arguments.contains("-skipOnboarding"), forKey: SettingsKey.onboardingDone)
        }
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar@numbers=latn"))
                .preferredColorScheme(.light)
                .tint(Theme.purple)
        }
        .modelContainer(container)
    }
}

/// UIKit appearance so navigation bars and tab bars use the brand font.
enum Appearance {
    static func configure() {
        let titleFont = UIFont(name: "Tajawal-Bold", size: 17) ?? .systemFont(ofSize: 17, weight: .bold)
        let largeFont = UIFont(name: "Tajawal-ExtraBold", size: 32) ?? .systemFont(ofSize: 32, weight: .heavy)
        let ink = UIColor(red: 0x20 / 255, green: 0x24 / 255, blue: 0x3A / 255, alpha: 1)
        let background = UIColor(red: 0xF7 / 255, green: 0xF8 / 255, blue: 0xFC / 255, alpha: 1)

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = background
        nav.titleTextAttributes = [.font: titleFont, .foregroundColor: ink]
        nav.largeTitleTextAttributes = [.font: largeFont, .foregroundColor: ink]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        let tabFont = UIFont(name: "Tajawal-Medium", size: 11) ?? .systemFont(ofSize: 11, weight: .medium)
        for layout in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            layout.normal.titleTextAttributes = [.font: tabFont]
            layout.selected.titleTextAttributes = [.font: tabFont]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
