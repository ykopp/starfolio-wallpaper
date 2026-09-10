// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "Starfolio", platforms: [.macOS(.v15)], products: [.executable(name: "Starfolio", targets: ["Starfolio"])], dependencies: [.package(path: "Packages/CelestialKit")], targets: [.executableTarget(name: "Starfolio", dependencies: ["CelestialKit"]), .testTarget(name: "StarfolioTests", dependencies: ["Starfolio", "CelestialKit"])])
