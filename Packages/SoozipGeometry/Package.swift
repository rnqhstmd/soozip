// swift-tools-version: 6.0
import PackageDescription

// platforms는 **Apple 플랫폼의 최소 버전만** 제약한다. Windows·Linux 빌드에는
// 영향이 없으므로 이 선언이 있어도 `swift test`는 Windows에서 그대로 돈다.
//
// macOS 13이 필요한 이유: SnapBench가 쓰는 Duration.components가 macOS 13+다.
// 선언이 없으면 기본 타깃이 10.13이 되어 `swift test`가 SnapBench 컴파일에서
// 죽는다 — 라이브러리와 테스트는 멀쩡한데 명령 전체가 실패한다.
let package = Package(
    name: "SoozipGeometry",
    platforms: [.iOS(.v17), .macOS(.v13)],
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
