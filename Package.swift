// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MacTranslator",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacTranslator",
            path: "Sources/MacTranslator"
        )
    ]
)
