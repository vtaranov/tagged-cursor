// swift-tools-version:5.9
import PackageDescription

// Пакет нужен только для тестов: само приложение собирается через build.sh (swiftc).
let package = Package(
    name: "TaggedCursorCore",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "TaggedCursorCore", path: "Sources/Core"),
        .testTarget(name: "CoreTests", dependencies: ["TaggedCursorCore"], path: "Tests/CoreTests"),
    ]
)
