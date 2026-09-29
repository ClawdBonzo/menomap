// swift-tools-version: 6.0
import PackageDescription

// MenoCore: pure-Swift domain types, calendar math, insight rules and stats.
// No UI, no SwiftData, no user-facing strings, so the whole package tests on the Mac with `swift test`.
let package = Package(
    name: "MenoCore",
    platforms: [.iOS(.v18), .watchOS(.v11), .macOS(.v15)],
    products: [.library(name: "MenoCore", targets: ["MenoCore"])],
    targets: [
        .target(name: "MenoCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "MenoCoreTests", dependencies: ["MenoCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
