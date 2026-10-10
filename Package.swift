// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentFloat",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "AgentFloatCore",
            targets: ["AgentFloatCore"]
        ),
        .executable(
            name: "AgentFloatApp",
            targets: ["AgentFloatApp"]
        ),
        .executable(
            name: "AgentFloatCLI",
            targets: ["AgentFloatCLI"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AgentFloatCore",
            dependencies: [],
            path: "Sources/AgentFloatCore"
        ),
        .executableTarget(
            name: "AgentFloatApp",
            dependencies: ["AgentFloatCore"],
            path: "Sources/AgentFloatApp",
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "AgentFloatCLI",
            dependencies: ["AgentFloatCore"],
            path: "Sources/AgentFloatCLI"
        ),
        .testTarget(
            name: "AgentFloatCoreTests",
            dependencies: ["AgentFloatCore"],
            path: "Tests/AgentFloatCoreTests"
        ),
    ]
)
