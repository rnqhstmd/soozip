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
        ),
        // 벤치마크는 테스트가 아니다(통과/실패가 아니라 수치를 낸다).
        // 반드시 `swift run -c release SnapBench`로 돌린다 — debug 빌드는
        // 수십 배 느려서 60fps 예산 판단에 쓸 수 없다.
        .executableTarget(
            name: "SnapBench",
            dependencies: ["SoozipGeometry"]
        )
    ]
)
