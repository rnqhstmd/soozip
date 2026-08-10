// swift-tools-version: 6.0
import PackageDescription

// platforms를 지정하지 않는다. 지정하면 Apple 플랫폼 최소 버전이 박히는데,
// 이 패키지는 Windows에서도 빌드·테스트되어야 한다.
// 앱 타깃의 iOS 17 요구는 앱 쪽에서 강제된다.
let package = Package(
    name: "SoozipGeometry",
    products: [
        .library(name: "SoozipGeometry", targets: ["SoozipGeometry"])
    ],
    targets: [
        .target(name: "SoozipGeometry"),
        .testTarget(
            name: "SoozipGeometryTests",
            dependencies: ["SoozipGeometry"]
        )
    ]
)
