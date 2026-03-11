// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MDMSSODemo",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "DemoShared",
            targets: ["DemoShared"]
        ),
        .library(
            name: "DemoLoginShellSupport",
            targets: ["DemoLoginShellSupport"]
        ),
        .library(
            name: "DemoLoginPluginSupport",
            targets: ["DemoLoginPluginSupport"]
        ),
        .library(
            name: "DemoAccountSyncSupport",
            targets: ["DemoAccountSyncSupport"]
        ),
        .executable(
            name: "DemoIDPServer",
            targets: ["DemoIDPServer"]
        ),
        .executable(
            name: "DemoLoginShell",
            targets: ["DemoLoginShell"]
        ),
        .executable(
            name: "DemoAccountSyncDaemon",
            targets: ["DemoAccountSyncDaemon"]
        ),
        .executable(
            name: "DemoLoginBroker",
            targets: ["DemoLoginBroker"]
        ),
    ],
    targets: [
        .target(
            name: "DemoShared"
        ),
        .target(
            name: "DemoAccountSyncSupport",
            dependencies: ["DemoShared"]
        ),
        .target(
            name: "DemoLoginShellSupport",
            dependencies: ["DemoShared", "DemoAccountSyncSupport"]
        ),
        .target(
            name: "DemoLoginPluginSupport",
            dependencies: ["DemoShared"]
        ),
        .target(
            name: "DemoLoginPluginC",
            dependencies: ["DemoLoginPluginSupport"],
            path: "Sources/DemoLoginPluginC",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("Foundation"),
            ]
        ),
        .executableTarget(
            name: "DemoIDPServer",
            dependencies: ["DemoShared"]
        ),
        .executableTarget(
            name: "DemoLoginShell",
            dependencies: ["DemoLoginShellSupport"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .executableTarget(
            name: "DemoAccountSyncDaemon",
            dependencies: ["DemoAccountSyncSupport"]
        ),
        .executableTarget(
            name: "DemoLoginBroker",
            dependencies: ["DemoLoginShellSupport", "DemoLoginPluginSupport", "DemoAccountSyncSupport"]
        ),
        .testTarget(
            name: "DemoSharedTests",
            dependencies: ["DemoShared"]
        ),
        .testTarget(
            name: "DemoAccountSyncSupportTests",
            dependencies: ["DemoAccountSyncSupport"]
        ),
        .testTarget(
            name: "DemoLoginShellSupportTests",
            dependencies: ["DemoLoginShellSupport"]
        ),
        .testTarget(
            name: "DemoLoginPluginSupportTests",
            dependencies: ["DemoLoginPluginSupport"]
        ),
    ]
)
