// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PowderCoatingRunEngine",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "PowderCoatingRunEngine", targets: ["PowderCoatingRunEngine"]),
        .executable(name: "powder-run-harness", targets: ["PowderRunHarness"])
    ],
    targets: [
        .target(name: "PowderCoatingRunEngine"),
        .executableTarget(name: "PowderRunHarness", dependencies: ["PowderCoatingRunEngine"]),
        .testTarget(name: "PowderCoatingRunEngineTests", dependencies: ["PowderCoatingRunEngine"],
                    resources: [.process("Fixtures")])
    ]
)
