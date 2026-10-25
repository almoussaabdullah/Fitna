// swift-tools-version:5.9
import PackageDescription

// FitnaKit holds every piece of game logic that does not depend on UIKit/SwiftUI:
// puzzle generators, game rules, scoring, adaptive difficulty, progression,
// achievements and the daily-workout / assessment planners.
// It builds and tests on macOS, iOS and Linux so the rules can be verified anywhere.
let package = Package(
    name: "FitnaKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FitnaKit", targets: ["FitnaKit"])
    ],
    targets: [
        .target(name: "FitnaKit"),
        .testTarget(name: "FitnaKitTests", dependencies: ["FitnaKit"])
    ]
)
