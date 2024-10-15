// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "ResultBuilderMacro",
    platforms: [.macOS(.v14), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ResultBuilderMacro",
            targets: ["ResultBuilderMacro"]
        ),
        .executable(
            name: "ResultBuilderMacroClient",
            targets: ["ResultBuilderMacroClient"]
        ),
    ],
    dependencies: [
        .package(path: "/Users/mateusrodrigues/Documents/swift-syntax"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "ResultBuilderMacroImplementation",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "ResultBuilderMacro",
            dependencies: ["ResultBuilderMacroImplementation"],
            swiftSettings: [
                .enableExperimentalFeature("BodyMacros")
            ]
        ),
        // A client of the library, which is able to use the macro in its own code.
        .executableTarget(
            name: "ResultBuilderMacroClient",
            dependencies: ["ResultBuilderMacro"],
            swiftSettings: [
                .enableExperimentalFeature("BodyMacros")
            ]
        ),
        // A test target used to develop the macro implementation.
        .testTarget(
            name: "ResultBuilderMacroTests",
            dependencies: [
                "ResultBuilderMacroImplementation",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
