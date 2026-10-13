// swift-tools-version:6.0
import PackageDescription

let package = Package(
  name: "KeyCount",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "KeyCountCore"),
    .executableTarget(name: "KeyCount", dependencies: ["KeyCountCore"]),
    // A plain executable rather than a test target: swift-testing does not discover tests under Command Line Tools alone.
    .executableTarget(name: "KeyCountChecks", dependencies: ["KeyCountCore"]),
  ],
  swiftLanguageModes: [.v5]
)
