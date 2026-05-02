// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Clarity",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "Clarity", targets: ["Clarity"])
    ],
    targets: [
        .executableTarget(
            name: "Clarity",
            path: "Sources"
        )
    ]
)
