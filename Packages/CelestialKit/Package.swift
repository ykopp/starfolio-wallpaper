// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "CelestialKit", platforms: [.macOS(.v15)], products: [.library(name: "CelestialKit", targets: ["CelestialKit"])], targets: [.target(name: "CelestialKit", resources: [.copy("Resources/astronomy")])])
