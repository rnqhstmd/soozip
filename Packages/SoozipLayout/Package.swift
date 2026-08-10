// swift-tools-version: 6.0
import PackageDescription

// SoozipGeometry와 같은 이유로 platforms를 지정하지 않는다 — Windows에서도
// 빌드·테스트되어야 한다. layoutJSON은 Foundation만으로 인코딩/디코딩된다.
let package = Package(
    name: "SoozipLayout",
    products: [
        .library(name: "SoozipLayout", targets: ["SoozipLayout"])
    ],
    dependencies: [
        .package(path: "../SoozipGeometry")
    ],
    targets: [
        .target(
            name: "SoozipLayout",
            dependencies: [.product(name: "SoozipGeometry", package: "SoozipGeometry")]
        ),
        .testTarget(
            name: "SoozipLayoutTests",
            dependencies: ["SoozipLayout"]
        )
    ]
)
