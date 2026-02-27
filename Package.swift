// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeTerminal",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ClaudeTerminal", targets: ["ClaudeTerminal"]),
        .executable(name: "ClaudeTerminalHelper", targets: ["ClaudeTerminalHelper"]),
        .library(name: "Shared", targets: ["Shared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.3.0"),
        .package(url: "https://github.com/trilemma-dev/SecureXPC", from: "0.8.0"),
    ],
    targets: [
        // Note: .defaultIsolation(MainActor.self) requires SPM 6.1+ (Xcode 16.3+).
        // Set defaultIsolation in the Xcode project's Swift Compiler settings instead.
        .executableTarget(
            name: "ClaudeTerminal",
            dependencies: [
                "Shared",
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "SecureXPC", package: "SecureXPC"),
            ],
            path: "ClaudeTerminal"
        ),
        .executableTarget(
            name: "ClaudeTerminalHelper",
            dependencies: [
                "Shared",
                .product(name: "SecureXPC", package: "SecureXPC"),
            ],
            path: "ClaudeTerminalHelper"
        ),
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "SecureXPC", package: "SecureXPC"),
            ],
            path: "Shared"
        ),
        .testTarget(
            name: "ClaudeTerminalTests",
            dependencies: ["Shared"],
            path: "ClaudeTerminalTests"
        ),
    ]
)
