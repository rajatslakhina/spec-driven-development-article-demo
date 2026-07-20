// swift-tools-version:5.10
// SpecGateKit — a small library that treats a feature spec as an executable
// artifact: parse it, bind acceptance criteria to real checks, and get a
// verification report that names what is proven, what failed, and what is
// merely hoped for.
//
// Companion demo app lives in Demo/Demo.xcodeproj (local package reference).
// Deliberately NO .executableTarget here: running a Swift Package directly as
// an iOS app relies on a per-checkout synthesized bundle identifier that is
// never committed to git and crashes on launch. The runnable app is a real
// .xcodeproj instead.
import PackageDescription

let package = Package(
    name: "SpecGateKit",
    products: [
        .library(name: "SpecGateKit", targets: ["SpecGateKit"])
    ],
    targets: [
        .target(name: "SpecGateKit"),
        .testTarget(name: "SpecGateKitTests", dependencies: ["SpecGateKit"])
    ]
)
