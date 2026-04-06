// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PropertyManager",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "PropertyManager",
            path: "PropertyManager",
            exclude: ["README.md", "Info.plist"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
