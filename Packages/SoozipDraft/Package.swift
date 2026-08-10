// swift-tools-version: 6.0
import PackageDescription

// 초안 저장소. FileManager만 쓰므로 Windows에서도 빌드·테스트된다.
// 루트 경로를 주입받는 설계라 앱에서는 Application Support/Drafts를,
// 테스트에서는 임시 폴더를 넘긴다.
let package = Package(
    name: "SoozipDraft",
    products: [
        .library(name: "SoozipDraft", targets: ["SoozipDraft"])
    ],
    dependencies: [
        .package(path: "../SoozipLayout")
    ],
    targets: [
        .target(
            name: "SoozipDraft",
            dependencies: [.product(name: "SoozipLayout", package: "SoozipLayout")]
        ),
        .testTarget(
            name: "SoozipDraftTests",
            dependencies: ["SoozipDraft"]
        )
    ]
)
