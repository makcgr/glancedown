// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Glancedown",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "RenderCore", targets: ["RenderCore"]),
        .executable(name: "Glancedown", targets: ["Glancedown"]),
        .executable(name: "GlancedownQuickLook", targets: ["GlancedownQuickLook"]),
        .executable(name: "GlancedownEditor", targets: ["GlancedownEditor"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-cmark.git", exact: "0.9.0"),
    ],
    targets: [
        .target(
            name: "RenderCore",
            dependencies: [
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            resources: [.copy("Web")]
        ),
        .executableTarget(
            name: "Glancedown",
            dependencies: ["RenderCore"]
        ),
        .executableTarget(
            name: "GlancedownQuickLook",
            dependencies: ["RenderCore"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"]),
                .linkedFramework("QuickLookUI"),
            ]
        ),
        .executableTarget(
            name: "GlancedownEditor",
            dependencies: ["RenderCore"]
        ),
        .executableTarget(
            name: "RenderSnapshot",
            dependencies: ["RenderCore"]
        ),
        .testTarget(
            name: "RenderCoreTests",
            dependencies: ["RenderCore"]
        ),
        .testTarget(
            name: "GlancedownEditorTests",
            dependencies: ["GlancedownEditor"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
