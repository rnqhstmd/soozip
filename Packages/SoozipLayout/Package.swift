// swift-tools-version: 6.0
import PackageDescription

// platforms는 Apple 플랫폼의 최소 버전만 제약한다 — Windows·Linux 빌드와 무관하다.
//
// 이 패키지 자체는 Foundation의 오래된 API만 쓰지만 선언이 필요하다.
// SPM은 **의존 대상보다 낮은 최소 버전을 허용하지 않는다.** SoozipGeometry가
// macOS 13을 요구하므로(SnapBench의 Duration.components) 이쪽도 맞춰야 한다.
let package = Package(
    name: "SoozipLayout",
    platforms: [.iOS(.v17), .macOS(.v13)],
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
