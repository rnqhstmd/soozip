# MoeumCore — 색 엔진 · 지역 데이터 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 「모음 집」의 색 혼합 규칙과 행정구역 조회를 UI 없이 완결된 Swift 패키지로 만든다.

**Architecture:** `MoeumCore`는 Apple 프레임워크에 의존하지 않는 순수 로직 SwiftPM 패키지다. 색 팔레트, 결정론적 난수, 지역 카탈로그, 색 집계, 메시 스펙 생성, 통계 계산까지 전부 값 타입과 순수 함수로 구성한다. SwiftUI 렌더링·SwiftData 저장은 이 패키지 밖(후속 계획)에서 이 패키지가 내놓은 데이터를 소비한다. 이 경계 덕분에 iOS 시뮬레이터 없이 `swift test`만으로 전 로직을 검증할 수 있고, macOS가 아닌 환경에서도 개발이 가능하다.

**Tech Stack:** Swift 5.9+, SwiftPM, XCTest, Foundation만 사용 (SwiftUI·CoreGraphics·SwiftData 금지)

## Global Constraints

- **패키지는 플랫폼 제약을 선언하지 않는다.** `Package.swift`에 `platforms:`를 넣지 않아 Windows/Linux/macOS에서 모두 빌드된다. iOS 17+ 제약은 이 패키지를 소비하는 앱 타깃에만 건다.
- **`import SwiftUI`, `import CoreGraphics`, `import UIKit`, `import SwiftData` 금지.** `import Foundation`만 허용한다.
- **파스텔 12색은 고정값이다.** 채도 `0.55`, 명도 `0.82`, 색상은 `index × 30.0`도. 이 세 값은 스펙 3.1절에서 확정된 것으로 임의 변경 금지.
- **`regionCode`는 10자리 문자열이다.** 시·도는 앞 2자리 + `"00000000"`, 시·군·구는 앞 5자리 + `"00000"`.
- **혼합에 참여하는 색은 최대 6개다.** 초과분은 버리지 않고 색상환에서 가장 가까운 생존색에 흡수시킨다.
- **축약 임계값은 짧은 변 20.0이다.** 이하이면 상위 2색 선형 표현으로 떨어뜨린다.
- **모든 계산은 결정론적이어야 한다.** 같은 입력은 항상 같은 출력을 낸다. `Date()`, `random()`, `Set`/`Dictionary` 순회 순서에 결과가 의존해서는 안 된다.
- 모든 public 타입은 `Sendable`, 값 비교가 필요한 것은 `Equatable`을 채택한다.

## 사전 준비 (Task 1 시작 전 1회)

**Swift 툴체인이 필요하다.** 현재 개발 머신(Windows)에는 설치되어 있지 않다.

- Windows: <https://www.swift.org/install/windows/> 에서 Swift 5.9 이상 설치 후 새 터미널에서 `swift --version` 확인
- macOS: Xcode 설치 시 함께 제공됨

**실제 행정구역 CSV는 Task 3에서 픽스처로 대체하고, 전체 데이터는 Task 3 마지막 단계에서 받는다.** 출처는 행정표준코드관리시스템(<https://www.code.go.kr>)의 "법정동코드 전체자료"이며, 받은 원본을 이 계획이 정의한 4컬럼 형식으로 변환해 넣는다. 변환 규칙은 Task 3에 명시되어 있다.

## File Structure

| 파일 | 책임 |
|---|---|
| `Package.swift` | SwiftPM 매니페스트. 플랫폼 무제약, XCTest 테스트 타깃 |
| `Sources/MoeumCore/Palette/PastelColor.swift` | 색 하나를 표현하는 값 타입 |
| `Sources/MoeumCore/Palette/PastelPalette.swift` | 12색 상수 테이블과 조회 |
| `Sources/MoeumCore/Random/SeededRandom.swift` | SplitMix64 결정론적 난수 |
| `Sources/MoeumCore/Random/RegionHash.swift` | 지역코드 → 시드 (FNV-1a 64) |
| `Sources/MoeumCore/Region/Region.swift` | 지역 값 타입과 계층 열거형 |
| `Sources/MoeumCore/Region/RegionCatalog.swift` | CSV 파싱, 지역 조회, 코드 검증 |
| `Sources/MoeumCore/Mesh/ColorWeight.swift` | 색별 비중 값 타입 |
| `Sources/MoeumCore/Mesh/ColorTally.swift` | 집계 · 상위 6색 절단 · 인접색 흡수 |
| `Sources/MoeumCore/Mesh/MeshSpec.swift` | 메시 블롭·스펙·표현 열거형 |
| `Sources/MoeumCore/Mesh/MeshComposer.swift` | 지역코드 + 색 배열 → MeshSpec |
| `Sources/MoeumCore/Stats/CanvasSummary.swift` | 통계 입력 값 타입 |
| `Sources/MoeumCore/Stats/StatsCalculator.swift` | 통계 6종 계산 |
| `Tests/MoeumCoreTests/*.swift` | 타깃별 테스트 |
| `Tests/MoeumCoreTests/Fixtures/regions-fixture.csv` | 테스트용 축소 카탈로그 |
| `Sources/MoeumCore/Resources/regions.csv` | 실제 전국 카탈로그 (Task 3에서 투입) |

파일을 기능별로 쪼갠 이유는, 각 파일이 한 가지 책임만 갖게 해서 후속 계획의 구현자가 필요한 파일만 열어보면 되게 하기 위함이다.

---

### Task 1: 패키지 스캐폴딩과 파스텔 12색

**Files:**
- Create: `Package.swift`
- Create: `Sources/MoeumCore/Palette/PastelColor.swift`
- Create: `Sources/MoeumCore/Palette/PastelPalette.swift`
- Test: `Tests/MoeumCoreTests/PastelPaletteTests.swift`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: `PastelColor(index:name:hue:saturation:lightness:)`, `PastelPalette.count: Int`, `PastelPalette.all: [PastelColor]`, `PastelPalette.color(at: Int) -> PastelColor`, `PastelPalette.hue(at: Int) -> Double`

- [ ] **Step 1: 저장소를 git으로 초기화하고 패키지 뼈대를 만든다**

`D:\SQ\moumzip`은 아직 git 저장소가 아니다.

```bash
cd D:/SQ/moumzip
git init
printf '.superpowers/\n.omc/\n.build/\n.swiftpm/\n' > .gitignore
mkdir -p Sources/MoeumCore/Palette Tests/MoeumCoreTests/Fixtures
```

`Package.swift`를 만든다. **`platforms:`를 넣지 않는 것이 핵심이다** — 넣으면 Windows 빌드가 깨진다.

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MoeumCore",
    products: [
        .library(name: "MoeumCore", targets: ["MoeumCore"])
    ],
    targets: [
        .target(name: "MoeumCore"),
        .testTarget(name: "MoeumCoreTests", dependencies: ["MoeumCore"])
    ]
)
```

- [ ] **Step 2: 실패하는 테스트를 작성한다**

`Tests/MoeumCoreTests/PastelPaletteTests.swift`:

```swift
import XCTest
@testable import MoeumCore

final class PastelPaletteTests: XCTestCase {

    func test_팔레트는_정확히_12색이다() {
        XCTAssertEqual(PastelPalette.count, 12)
        XCTAssertEqual(PastelPalette.all.count, 12)
    }

    func test_색상은_30도_등간격이다() {
        for index in 0..<12 {
            XCTAssertEqual(PastelPalette.all[index].hue, Double(index) * 30.0, accuracy: 0.0001)
        }
    }

    func test_채도와_명도는_전_색상_동일하다() {
        for color in PastelPalette.all {
            XCTAssertEqual(color.saturation, 0.55, accuracy: 0.0001)
            XCTAssertEqual(color.lightness, 0.82, accuracy: 0.0001)
        }
    }

    func test_인덱스와_이름이_스펙과_일치한다() {
        XCTAssertEqual(PastelPalette.color(at: 0).name, "로즈")
        XCTAssertEqual(PastelPalette.color(at: 5).name, "민트")
        XCTAssertEqual(PastelPalette.color(at: 11).name, "체리")
        XCTAssertEqual(PastelPalette.color(at: 5).index, 5)
    }

    func test_이름은_모두_고유하다() {
        let names = PastelPalette.all.map(\.name)
        XCTAssertEqual(Set(names).count, 12)
    }
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인한다**

```bash
swift test --filter PastelPaletteTests
```

기대: 컴파일 실패. `cannot find 'PastelPalette' in scope`

- [ ] **Step 4: 최소 구현을 작성한다**

`Sources/MoeumCore/Palette/PastelColor.swift`:

```swift
/// 팔레트 색 하나. 채도·명도는 전 색상 고정이며 색상(hue)만 다르다.
public struct PastelColor: Equatable, Sendable {
    public let index: Int
    public let name: String
    /// 0 이상 360 미만
    public let hue: Double
    /// 0...1
    public let saturation: Double
    /// 0...1
    public let lightness: Double

    public init(index: Int, name: String, hue: Double, saturation: Double, lightness: Double) {
        self.index = index
        self.name = name
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
    }
}
```

`Sources/MoeumCore/Palette/PastelPalette.swift`:

```swift
/// 파스텔 12색 고정 팔레트. 색상환을 30도 등간격으로 나눈다.
public enum PastelPalette {

    public static let count = 12

    /// 스펙 3.1절 확정값. 변경 금지.
    public static let fixedSaturation = 0.55
    public static let fixedLightness = 0.82
    public static let hueStep = 30.0

    private static let names = [
        "로즈", "피치", "버터", "라임", "세이지", "민트",
        "아쿠아", "스카이", "블루", "라벤더", "모브", "체리"
    ]

    public static let all: [PastelColor] = (0..<count).map { index in
        PastelColor(
            index: index,
            name: names[index],
            hue: Double(index) * hueStep,
            saturation: fixedSaturation,
            lightness: fixedLightness
        )
    }

    /// 범위를 벗어난 인덱스는 12로 나눈 나머지로 감싼다.
    public static func color(at index: Int) -> PastelColor {
        all[((index % count) + count) % count]
    }

    public static func hue(at index: Int) -> Double {
        color(at: index).hue
    }
}
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

```bash
swift test --filter PastelPaletteTests
```

기대: 5개 테스트 모두 PASS

- [ ] **Step 6: 커밋한다**

```bash
git add Package.swift .gitignore Sources/MoeumCore/Palette Tests/MoeumCoreTests/PastelPaletteTests.swift
git commit -m "feat: MoeumCore 패키지 스캐폴딩과 파스텔 12색 팔레트"
```

---

### Task 2: 결정론적 난수와 지역코드 시드

**Files:**
- Create: `Sources/MoeumCore/Random/SeededRandom.swift`
- Create: `Sources/MoeumCore/Random/RegionHash.swift`
- Test: `Tests/MoeumCoreTests/SeededRandomTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces: `SeededRandom(seed: UInt64)`, `mutating func next() -> Double` (0 이상 1 미만), `RegionHash.seed(for: String) -> UInt64`

메시 배치가 "열 때마다 달라 보이는" 사고를 막으려면 표준 라이브러리의 `random()`을 쓸 수 없다. 플랫폼·실행마다 결과가 달라지기 때문이다. 직접 구현한 SplitMix64를 쓴다.

- [ ] **Step 1: 실패하는 테스트를 작성한다**

`Tests/MoeumCoreTests/SeededRandomTests.swift`:

```swift
import XCTest
@testable import MoeumCore

final class SeededRandomTests: XCTestCase {

    func test_같은_시드는_같은_수열을_낸다() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        for _ in 0..<50 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func test_다른_시드는_다른_수열을_낸다() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        let lhs = (0..<10).map { _ in a.next() }
        let rhs = (0..<10).map { _ in b.next() }
        XCTAssertNotEqual(lhs, rhs)
    }

    func test_출력은_0이상_1미만이다() {
        var rng = SeededRandom(seed: 987654321)
        for _ in 0..<1000 {
            let value = rng.next()
            XCTAssertGreaterThanOrEqual(value, 0.0)
            XCTAssertLessThan(value, 1.0)
        }
    }

    func test_연속_호출은_서로_다른_값을_낸다() {
        var rng = SeededRandom(seed: 7)
        let first = rng.next()
        let second = rng.next()
        XCTAssertNotEqual(first, second)
    }

    func test_지역코드_시드는_결정론적이다() {
        XCTAssertEqual(RegionHash.seed(for: "1120000000"), RegionHash.seed(for: "1120000000"))
    }

    func test_다른_지역코드는_다른_시드를_낸다() {
        XCTAssertNotEqual(RegionHash.seed(for: "1120000000"), RegionHash.seed(for: "1144000000"))
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

```bash
swift test --filter SeededRandomTests
```

기대: 컴파일 실패. `cannot find 'SeededRandom' in scope`

- [ ] **Step 3: 최소 구현을 작성한다**

`Sources/MoeumCore/Random/SeededRandom.swift`:

```swift
/// SplitMix64 기반 결정론적 난수 생성기.
/// 표준 라이브러리 난수는 플랫폼·실행마다 결과가 달라 메시 배치에 쓸 수 없다.
public struct SeededRandom: Sendable {

    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    /// 0 이상 1 미만의 실수를 낸다.
    public mutating func next() -> Double {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        // 상위 53비트만 써서 Double 정밀도 안에 정확히 담는다.
        return Double(z >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}
```

`Sources/MoeumCore/Random/RegionHash.swift`:

```swift
/// 지역코드 문자열을 난수 시드로 바꾼다. FNV-1a 64비트.
public enum RegionHash {

    public static func seed(for regionCode: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in regionCode.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

```bash
swift test --filter SeededRandomTests
```

기대: 6개 테스트 모두 PASS

- [ ] **Step 5: 커밋한다**

```bash
git add Sources/MoeumCore/Random Tests/MoeumCoreTests/SeededRandomTests.swift
git commit -m "feat: SplitMix64 결정론적 난수와 지역코드 시드"
```

---

### Task 3: 지역 카탈로그

**Files:**
- Create: `Sources/MoeumCore/Region/Region.swift`
- Create: `Sources/MoeumCore/Region/RegionCatalog.swift`
- Create: `Tests/MoeumCoreTests/Fixtures/regions-fixture.csv`
- Test: `Tests/MoeumCoreTests/RegionCatalogTests.swift`
- Modify: `Package.swift` (리소스 선언 추가)

**Interfaces:**
- Consumes: 없음
- Produces: `Region(code:name:parentCode:level:)`, `RegionLevel.province` / `.district`, `RegionCatalog(csv: String) throws`, `catalog.provinces: [Region]`, `catalog.districts(of: String) -> [Region]`, `catalog.region(code: String) -> Region?`, `catalog.districtCount: Int`, `RegionCatalog.provinceCode(from: String) -> String`, `RegionCatalogError`

**CSV 형식** — 헤더 1줄 + 데이터. 컬럼은 `code,name,parentCode,level`.

- `code`: 10자리 숫자 문자열
- `name`: 지역명
- `parentCode`: 시·도는 빈 문자열, 시·군·구는 소속 시·도 코드
- `level`: `province` 또는 `district`

실제 데이터를 만들 때는 행정표준코드관리시스템의 법정동코드 전체자료에서 **폐지되지 않은 행만** 남기고, 코드가 `XX00000000` 형태면 `province`, `XXXXX00000` 형태면 `district`로 분류한다. 그보다 하위(읍면동)는 이번 범위에서 제외한다.

- [ ] **Step 1: 테스트 픽스처 CSV를 만든다**

`Tests/MoeumCoreTests/Fixtures/regions-fixture.csv`:

```csv
code,name,parentCode,level
1100000000,서울특별시,,province
1120000000,성동구,1100000000,district
1144000000,마포구,1100000000,district
1111000000,종로구,1100000000,district
2600000000,부산광역시,,province
2611000000,중구,2600000000,district
3600000000,세종특별자치시,,province
3611000000,세종특별자치시,3600000000,district
```

세종은 하위 시·군·구가 없는 예외라 자기 자신을 district로 한 번 더 넣는다. 스펙 2.3절의 결정을 데이터로 표현한 것이다.

- [ ] **Step 2: 실패하는 테스트를 작성한다**

`Tests/MoeumCoreTests/RegionCatalogTests.swift`:

```swift
import XCTest
@testable import MoeumCore

final class RegionCatalogTests: XCTestCase {

    private let csv = """
    code,name,parentCode,level
    1100000000,서울특별시,,province
    1120000000,성동구,1100000000,district
    1144000000,마포구,1100000000,district
    1111000000,종로구,1100000000,district
    2600000000,부산광역시,,province
    2611000000,중구,2600000000,district
    3600000000,세종특별자치시,,province
    3611000000,세종특별자치시,3600000000,district
    """

    func test_시도와_시군구를_분리해_읽는다() throws {
        let catalog = try RegionCatalog(csv: csv)
        XCTAssertEqual(catalog.provinces.count, 3)
        XCTAssertEqual(catalog.districtCount, 5)
    }

    func test_시도_순서는_CSV_순서를_유지한다() throws {
        let catalog = try RegionCatalog(csv: csv)
        XCTAssertEqual(catalog.provinces.map(\.name), ["서울특별시", "부산광역시", "세종특별자치시"])
    }

    func test_시도로_하위_시군구를_찾는다() throws {
        let catalog = try RegionCatalog(csv: csv)
        let seoul = catalog.districts(of: "1100000000")
        XCTAssertEqual(seoul.map(\.name), ["성동구", "마포구", "종로구"])
    }

    func test_하위가_하나뿐인_세종도_동일하게_처리된다() throws {
        let catalog = try RegionCatalog(csv: csv)
        XCTAssertEqual(catalog.districts(of: "3600000000").count, 1)
    }

    func test_없는_시도는_빈_배열을_낸다() throws {
        let catalog = try RegionCatalog(csv: csv)
        XCTAssertEqual(catalog.districts(of: "9900000000"), [])
    }

    func test_코드로_지역을_찾는다() throws {
        let catalog = try RegionCatalog(csv: csv)
        XCTAssertEqual(catalog.region(code: "1120000000")?.name, "성동구")
        XCTAssertNil(catalog.region(code: "1120010900"))
    }

    func test_지역코드에서_시도코드_2자리를_뽑는다() {
        XCTAssertEqual(RegionCatalog.provinceCode(from: "1120000000"), "11")
        XCTAssertEqual(RegionCatalog.provinceCode(from: "2611000000"), "26")
    }

    func test_열_자리가_아닌_코드는_거부한다() {
        let bad = """
        code,name,parentCode,level
        11200,성동구,1100000000,district
        """
        XCTAssertThrowsError(try RegionCatalog(csv: bad)) { error in
            XCTAssertEqual(error as? RegionCatalogError, .invalidCode("11200"))
        }
    }

    func test_컬럼이_모자란_행은_거부한다() {
        let bad = """
        code,name,parentCode,level
        1120000000,성동구,1100000000
        """
        XCTAssertThrowsError(try RegionCatalog(csv: bad)) { error in
            XCTAssertEqual(error as? RegionCatalogError, .malformedRow(2))
        }
    }

    func test_알_수_없는_계층은_거부한다() {
        let bad = """
        code,name,parentCode,level
        1120010900,성수동1가,1120000000,dong
        """
        XCTAssertThrowsError(try RegionCatalog(csv: bad)) { error in
            XCTAssertEqual(error as? RegionCatalogError, .unknownLevel("dong"))
        }
    }

    func test_빈_줄은_무시한다() throws {
        let withBlank = csv + "\n\n"
        let catalog = try RegionCatalog(csv: withBlank)
        XCTAssertEqual(catalog.districtCount, 5)
    }
}
```

- [ ] **Step 3: 테스트가 실패하는지 확인한다**

```bash
swift test --filter RegionCatalogTests
```

기대: 컴파일 실패. `cannot find 'RegionCatalog' in scope`

- [ ] **Step 4: 최소 구현을 작성한다**

`Sources/MoeumCore/Region/Region.swift`:

```swift
public enum RegionLevel: String, Equatable, Sendable {
    case province
    case district
}

public struct Region: Equatable, Sendable {
    /// 10자리 법정동코드
    public let code: String
    public let name: String
    /// 시·도는 nil, 시·군·구는 소속 시·도 코드
    public let parentCode: String?
    public let level: RegionLevel

    public init(code: String, name: String, parentCode: String?, level: RegionLevel) {
        self.code = code
        self.name = name
        self.parentCode = parentCode
        self.level = level
    }
}
```

`Sources/MoeumCore/Region/RegionCatalog.swift`:

```swift
import Foundation

public enum RegionCatalogError: Error, Equatable, Sendable {
    /// 10자리 숫자가 아닌 코드
    case invalidCode(String)
    /// 컬럼 개수가 4가 아닌 행 (1-based 줄 번호)
    case malformedRow(Int)
    /// province / district 가 아닌 계층 값
    case unknownLevel(String)
}

/// 전국 행정구역 카탈로그. CSV 한 장을 읽어 조회 구조를 만든다.
public struct RegionCatalog: Sendable {

    public let provinces: [Region]
    private let districtsByProvince: [String: [Region]]
    private let byCode: [String: Region]
    private let allDistricts: [Region]

    public var districtCount: Int { allDistricts.count }

    public init(csv: String) throws {
        var provinces: [Region] = []
        var districts: [Region] = []
        var byCode: [String: Region] = [:]

        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

        for (offset, rawLine) in lines.enumerated() {
            let lineNumber = offset + 1
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if lineNumber == 1 && line.hasPrefix("code,") { continue }

            let columns = line.split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespaces) }
            guard columns.count == 4 else {
                throw RegionCatalogError.malformedRow(lineNumber)
            }

            let code = columns[0]
            guard code.count == 10, code.allSatisfy(\.isNumber) else {
                throw RegionCatalogError.invalidCode(code)
            }

            guard let level = RegionLevel(rawValue: columns[3]) else {
                throw RegionCatalogError.unknownLevel(columns[3])
            }

            let parent = columns[2].isEmpty ? nil : columns[2]
            let region = Region(code: code, name: columns[1], parentCode: parent, level: level)

            byCode[code] = region
            switch level {
            case .province: provinces.append(region)
            case .district: districts.append(region)
            }
        }

        self.provinces = provinces
        self.allDistricts = districts
        self.byCode = byCode
        // CSV 등장 순서를 유지한다. Dictionary 순회 순서에 의존하지 않기 위함.
        var grouped: [String: [Region]] = [:]
        for district in districts {
            guard let parent = district.parentCode else { continue }
            grouped[parent, default: []].append(district)
        }
        self.districtsByProvince = grouped
    }

    public func districts(of provinceCode: String) -> [Region] {
        districtsByProvince[provinceCode] ?? []
    }

    public func region(code: String) -> Region? {
        byCode[code]
    }

    /// 10자리 지역코드에서 시·도 식별용 앞 2자리를 뽑는다.
    public static func provinceCode(from regionCode: String) -> String {
        String(regionCode.prefix(2))
    }
}
```

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

```bash
swift test --filter RegionCatalogTests
```

기대: 11개 테스트 모두 PASS

- [ ] **Step 6: 실제 전국 CSV를 투입한다**

`Sources/MoeumCore/Resources/regions.csv`를 만들고, 사전 준비에서 받은 법정동코드 전체자료를 위 4컬럼 형식으로 변환해 넣는다.

원본은 탭 구분 텍스트 파일이며 컬럼은 `법정동코드 · 법정동명 · 폐지여부` 세 개다. 변환 규칙은 다음과 같다.

1. `폐지여부`가 `존재`가 아닌 행은 버린다
2. 코드가 `\d{2}00000000` 패턴이면 `level=province`, `parentCode`는 빈 문자열
3. 코드가 `\d{5}00000` 패턴이면 `level=district`, `parentCode`는 앞 2자리 + `"00000000"`
4. 그 외(읍·면·동 이하)는 전부 버린다 — 이번 범위 밖이다
5. `법정동명`에서 상위 지명을 떼고 마지막 토큰만 남긴다 (`서울특별시 성동구` → `성동구`)
6. **세종은 예외다.** `3600000000 세종특별자치시`는 province로 들어가지만 하위 district가 없으므로, `3611000000,세종특별자치시,3600000000,district` 한 행을 손으로 추가한다 (코드는 원본의 세종 하위 코드 중 하나를 쓴다)

결과는 시·도 17행 + 시·군·구 전체 행이다.

`Package.swift`의 `.target`을 리소스 포함으로 바꾼다:

```swift
.target(
    name: "MoeumCore",
    resources: [.copy("Resources/regions.csv")]
),
```

번들에서 읽는 편의 생성자를 `RegionCatalog.swift` 끝에 추가한다:

```swift
public extension RegionCatalog {

    enum BundleError: Error, Equatable, Sendable {
        case resourceNotFound
    }

    /// 패키지에 번들된 전국 카탈로그를 읽는다.
    static func bundled() throws -> RegionCatalog {
        guard let url = Bundle.module.url(forResource: "regions", withExtension: "csv") else {
            throw BundleError.resourceNotFound
        }
        return try RegionCatalog(csv: String(contentsOf: url, encoding: .utf8))
    }
}
```

- [ ] **Step 7: 실제 데이터 검증 테스트를 추가하고 실행한다**

`Tests/MoeumCoreTests/RegionCatalogTests.swift` 끝에 추가:

```swift
extension RegionCatalogTests {

    func test_번들_카탈로그의_시도는_17개다() throws {
        let catalog = try RegionCatalog.bundled()
        XCTAssertEqual(catalog.provinces.count, 17)
    }

    func test_모든_시도는_하위_시군구를_최소_하나_갖는다() throws {
        let catalog = try RegionCatalog.bundled()
        for province in catalog.provinces {
            XCTAssertFalse(
                catalog.districts(of: province.code).isEmpty,
                "\(province.name)에 하위 시·군·구가 없습니다"
            )
        }
    }

    func test_모든_시군구_코드는_앞_2자리가_상위_시도와_일치한다() throws {
        let catalog = try RegionCatalog.bundled()
        for province in catalog.provinces {
            let expected = RegionCatalog.provinceCode(from: province.code)
            for district in catalog.districts(of: province.code) {
                XCTAssertEqual(RegionCatalog.provinceCode(from: district.code), expected)
            }
        }
    }

    func test_시도_코드는_뒤_8자리가_0이다() throws {
        let catalog = try RegionCatalog.bundled()
        for province in catalog.provinces {
            XCTAssertTrue(province.code.hasSuffix("00000000"), province.code)
        }
    }

    func test_시군구_코드는_뒤_5자리가_0이다() throws {
        let catalog = try RegionCatalog.bundled()
        for province in catalog.provinces {
            for district in catalog.districts(of: province.code) {
                XCTAssertTrue(district.code.hasSuffix("00000"), district.code)
            }
        }
    }
}
```

```bash
swift test --filter RegionCatalogTests
```

기대: 16개 테스트 모두 PASS

- [ ] **Step 8: 커밋한다**

```bash
git add Package.swift Sources/MoeumCore/Region Sources/MoeumCore/Resources Tests/MoeumCoreTests/RegionCatalogTests.swift Tests/MoeumCoreTests/Fixtures
git commit -m "feat: 행정구역 카탈로그 CSV 로더와 전국 데이터"
```

---

### Task 4: 색 집계와 상위 6색 절단

**Files:**
- Create: `Sources/MoeumCore/Mesh/ColorWeight.swift`
- Create: `Sources/MoeumCore/Mesh/ColorTally.swift`
- Test: `Tests/MoeumCoreTests/ColorTallyTests.swift`

**Interfaces:**
- Consumes: `PastelPalette.count` (Task 1)
- Produces: `ColorWeight(colorIndex: Int, weight: Double)`, `ColorTally.maxColors: Int`, `ColorTally.weights(from: [Int]) -> [ColorWeight]`

알고리즘은 스펙 3.2절 1~2단계다. 색별로 세고, 고유 색이 6개를 넘으면 비중 낮은 것부터 잘라내되 **버리지 않고 색상환에서 가장 가까운 생존색에 개수를 더한다.**

동점 처리는 결정론을 위해 반드시 고정한다 — 개수가 같으면 **인덱스가 작은 쪽이 살아남고**, 흡수 대상 거리가 같으면 **인덱스가 작은 쪽으로 흡수**한다.

- [ ] **Step 1: 실패하는 테스트를 작성한다**

`Tests/MoeumCoreTests/ColorTallyTests.swift`:

```swift
import XCTest
@testable import MoeumCore

final class ColorTallyTests: XCTestCase {

    func test_빈_입력은_빈_결과를_낸다() {
        XCTAssertEqual(ColorTally.weights(from: []), [])
    }

    func test_단색은_비중_1이다() {
        let result = ColorTally.weights(from: [5])
        XCTAssertEqual(result, [ColorWeight(colorIndex: 5, weight: 1.0)])
    }

    func test_같은_색이_여러_장이어도_비중은_1이다() {
        let result = ColorTally.weights(from: [5, 5, 5])
        XCTAssertEqual(result, [ColorWeight(colorIndex: 5, weight: 1.0)])
    }

    func test_민트3_피치1은_비중_075_025다() {
        let result = ColorTally.weights(from: [5, 5, 5, 1])
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].colorIndex, 1)
        XCTAssertEqual(result[0].weight, 0.25, accuracy: 0.0001)
        XCTAssertEqual(result[1].colorIndex, 5)
        XCTAssertEqual(result[1].weight, 0.75, accuracy: 0.0001)
    }

    func test_결과는_색인덱스_오름차순이다() {
        let result = ColorTally.weights(from: [9, 1, 5])
        XCTAssertEqual(result.map(\.colorIndex), [1, 5, 9])
    }

    func test_비중의_합은_항상_1이다() {
        let result = ColorTally.weights(from: [0, 1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(result.reduce(0) { $0 + $1.weight }, 1.0, accuracy: 0.0001)
    }

    func test_고유색이_6개_이하면_그대로_유지된다() {
        let result = ColorTally.weights(from: [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(result.count, 6)
    }

    func test_7색_이상이면_상위_6색만_남는다() {
        // 개수: 0→7, 1→6, 2→5, 3→4, 4→3, 5→2, 6→1  (총 28장)
        var indices: [Int] = []
        for (colorIndex, count) in [(0, 7), (1, 6), (2, 5), (3, 4), (4, 3), (5, 2), (6, 1)] {
            indices.append(contentsOf: Array(repeating: colorIndex, count: count))
        }
        let result = ColorTally.weights(from: indices)
        XCTAssertEqual(result.count, 6)
        XCTAssertEqual(result.map(\.colorIndex), [0, 1, 2, 3, 4, 5])
    }

    func test_잘린_색은_가장_가까운_생존색에_흡수된다() {
        // 위와 같은 입력. 색 6(1장)은 색 5와 인접(거리 1)하므로 5에 흡수 → 5는 2+1=3장
        var indices: [Int] = []
        for (colorIndex, count) in [(0, 7), (1, 6), (2, 5), (3, 4), (4, 3), (5, 2), (6, 1)] {
            indices.append(contentsOf: Array(repeating: colorIndex, count: count))
        }
        let result = ColorTally.weights(from: indices)
        let mintish = result.first { $0.colorIndex == 5 }
        XCTAssertEqual(mintish?.weight ?? 0, 3.0 / 28.0, accuracy: 0.0001)
        XCTAssertEqual(result.reduce(0) { $0 + $1.weight }, 1.0, accuracy: 0.0001)
    }

    func test_색상환은_원형이라_11과_0은_인접이다() {
        // 0이 6장, 2·4·6·8·10이 각 2장, 11이 1장 → 7색이라 11이 잘린다.
        // 11과 0의 원형 거리는 1로 최소이므로 0에 흡수된다.
        var indices = Array(repeating: 0, count: 6)
        for colorIndex in [2, 4, 6, 8, 10] {
            indices.append(contentsOf: [colorIndex, colorIndex])
        }
        indices.append(11)
        let result = ColorTally.weights(from: indices)
        XCTAssertEqual(result.count, 6)
        let rose = result.first { $0.colorIndex == 0 }
        XCTAssertEqual(rose?.weight ?? 0, 7.0 / 17.0, accuracy: 0.0001)
    }

    func test_같은_입력은_항상_같은_결과를_낸다() {
        let indices = [0, 3, 3, 7, 7, 7, 11, 2, 9, 9]
        XCTAssertEqual(ColorTally.weights(from: indices), ColorTally.weights(from: indices))
    }

    func test_입력_순서가_달라도_결과는_같다() {
        XCTAssertEqual(
            ColorTally.weights(from: [5, 5, 1]),
            ColorTally.weights(from: [1, 5, 5])
        )
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

```bash
swift test --filter ColorTallyTests
```

기대: 컴파일 실패. `cannot find 'ColorTally' in scope`

- [ ] **Step 3: 최소 구현을 작성한다**

`Sources/MoeumCore/Mesh/ColorWeight.swift`:

```swift
/// 한 지역에서 특정 색이 차지하는 비중.
public struct ColorWeight: Equatable, Sendable {
    public let colorIndex: Int
    /// 0...1. 같은 지역의 모든 ColorWeight를 더하면 1이 된다.
    public let weight: Double

    public init(colorIndex: Int, weight: Double) {
        self.colorIndex = colorIndex
        self.weight = weight
    }
}
```

`Sources/MoeumCore/Mesh/ColorTally.swift`:

```swift
/// 캔버스 색 배열을 비중으로 집계한다. 스펙 3.2절 1~2단계.
public enum ColorTally {

    /// 메시에 참여하는 최대 색 개수.
    public static let maxColors = 6

    public static func weights(from colorIndices: [Int]) -> [ColorWeight] {
        guard !colorIndices.isEmpty else { return [] }

        // 1. 색별 개수 집계. 배열로 세어 Dictionary 순회 순서 의존을 피한다.
        var counts = [Int](repeating: 0, count: PastelPalette.count)
        for index in colorIndices {
            counts[((index % PastelPalette.count) + PastelPalette.count) % PastelPalette.count] += 1
        }

        var present = (0..<PastelPalette.count).filter { counts[$0] > 0 }

        // 2. 6색 초과분을 잘라 가장 가까운 생존색에 흡수시킨다.
        if present.count > maxColors {
            // 개수 내림차순, 동점이면 인덱스 오름차순으로 살아남는다.
            let ranked = present.sorted { lhs, rhs in
                counts[lhs] == counts[rhs] ? lhs < rhs : counts[lhs] > counts[rhs]
            }
            let survivors = Array(ranked.prefix(maxColors)).sorted()
            let dropped = ranked.dropFirst(maxColors)

            for droppedIndex in dropped {
                let target = nearestColor(to: droppedIndex, among: survivors)
                counts[target] += counts[droppedIndex]
                counts[droppedIndex] = 0
            }
            present = survivors
        }

        let total = present.reduce(0) { $0 + counts[$1] }
        return present.map { index in
            ColorWeight(colorIndex: index, weight: Double(counts[index]) / Double(total))
        }
    }

    /// 색상환은 원형이므로 11과 0의 거리는 1이다. 동점이면 인덱스가 작은 쪽.
    private static func nearestColor(to index: Int, among candidates: [Int]) -> Int {
        var best = candidates[0]
        var bestDistance = circularDistance(index, best)
        for candidate in candidates.dropFirst() {
            let distance = circularDistance(index, candidate)
            if distance < bestDistance {
                best = candidate
                bestDistance = distance
            }
        }
        return best
    }

    private static func circularDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let raw = abs(lhs - rhs)
        return min(raw, PastelPalette.count - raw)
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

```bash
swift test --filter ColorTallyTests
```

기대: 12개 테스트 모두 PASS

- [ ] **Step 5: 커밋한다**

```bash
git add Sources/MoeumCore/Mesh Tests/MoeumCoreTests/ColorTallyTests.swift
git commit -m "feat: 색 집계와 상위 6색 절단·인접색 흡수"
```

---

### Task 5: 메시 스펙 생성

**Files:**
- Create: `Sources/MoeumCore/Mesh/MeshSpec.swift`
- Create: `Sources/MoeumCore/Mesh/MeshComposer.swift`
- Test: `Tests/MoeumCoreTests/MeshComposerTests.swift`

**Interfaces:**
- Consumes: `ColorTally.weights(from:)` (Task 4), `SeededRandom`, `RegionHash.seed(for:)` (Task 2)
- Produces: `MeshBlob(colorIndex:weight:centerX:centerY:spread:alpha:)`, `MeshSpec(blobs: [MeshBlob])`, `MeshSpec.isEmpty: Bool`, `MeshComposer.compose(regionCode: String, colorIndices: [Int]) -> MeshSpec`

스펙 3.2절 3~4단계다. **가장 중요한 성질은 블롭 위치가 `(지역코드, 색인덱스)`로만 결정된다는 것**이다. 캔버스를 몇 장 더 얹어도 기존 색의 좌표가 움직이면 안 된다.

- [ ] **Step 1: 실패하는 테스트를 작성한다**

`Tests/MoeumCoreTests/MeshComposerTests.swift`:

```swift
import XCTest
@testable import MoeumCore

final class MeshComposerTests: XCTestCase {

    private let seongdong = "1120000000"
    private let mapo = "1144000000"

    func test_캔버스가_없으면_빈_스펙이다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [])
        XCTAssertTrue(spec.isEmpty)
        XCTAssertEqual(spec.blobs, [])
    }

    func test_블롭_개수는_고유색_개수와_같다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [5, 5, 1, 9])
        XCTAssertEqual(spec.blobs.count, 3)
    }

    func test_블롭은_색인덱스_오름차순이다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [9, 1, 5])
        XCTAssertEqual(spec.blobs.map(\.colorIndex), [1, 5, 9])
    }

    func test_같은_입력은_항상_같은_스펙을_낸다() {
        let first = MeshComposer.compose(regionCode: seongdong, colorIndices: [5, 1, 1])
        let second = MeshComposer.compose(regionCode: seongdong, colorIndices: [5, 1, 1])
        XCTAssertEqual(first, second)
    }

    func test_다른_지역은_다른_배치를_낸다() {
        let a = MeshComposer.compose(regionCode: seongdong, colorIndices: [5])
        let b = MeshComposer.compose(regionCode: mapo, colorIndices: [5])
        XCTAssertNotEqual(a.blobs[0].centerX, b.blobs[0].centerX)
    }

    func test_색을_더해도_기존_색의_좌표는_움직이지_않는다() {
        let before = MeshComposer.compose(regionCode: seongdong, colorIndices: [5])
        let after = MeshComposer.compose(regionCode: seongdong, colorIndices: [5, 1, 9])

        let mintBefore = before.blobs.first { $0.colorIndex == 5 }
        let mintAfter = after.blobs.first { $0.colorIndex == 5 }

        XCTAssertEqual(mintBefore?.centerX, mintAfter?.centerX)
        XCTAssertEqual(mintBefore?.centerY, mintAfter?.centerY)
    }

    func test_같은_색을_더_쌓아도_스펙이_그대로다() {
        let one = MeshComposer.compose(regionCode: seongdong, colorIndices: [5])
        let three = MeshComposer.compose(regionCode: seongdong, colorIndices: [5, 5, 5])
        XCTAssertEqual(one, three)
    }

    func test_비중이_클수록_번짐과_진하기가_크다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [5, 5, 5, 1])
        let mint = spec.blobs.first { $0.colorIndex == 5 }!
        let peach = spec.blobs.first { $0.colorIndex == 1 }!
        XCTAssertGreaterThan(mint.spread, peach.spread)
        XCTAssertGreaterThan(mint.alpha, peach.alpha)
    }

    func test_중심은_캔버스_안에_있다() {
        for colorIndex in 0..<12 {
            let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [colorIndex])
            let blob = spec.blobs[0]
            XCTAssertGreaterThanOrEqual(blob.centerX, 0.0)
            XCTAssertLessThanOrEqual(blob.centerX, 1.0)
            XCTAssertGreaterThanOrEqual(blob.centerY, 0.0)
            XCTAssertLessThanOrEqual(blob.centerY, 1.0)
        }
    }

    func test_번짐과_진하기는_스펙_공식과_일치한다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [5])
        let blob = spec.blobs[0]
        // weight == 1.0
        XCTAssertEqual(blob.spread, 0.55 + 0.75, accuracy: 0.0001)
        XCTAssertEqual(blob.alpha, 0.55 + 0.45, accuracy: 0.0001)
    }

    func test_일곱색_이상이면_블롭은_여섯개다() {
        let spec = MeshComposer.compose(regionCode: seongdong,
                                        colorIndices: [0, 1, 2, 3, 4, 5, 6, 7, 8])
        XCTAssertEqual(spec.blobs.count, 6)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

```bash
swift test --filter MeshComposerTests
```

기대: 컴파일 실패. `cannot find 'MeshComposer' in scope`

- [ ] **Step 3: 최소 구현을 작성한다**

`Sources/MoeumCore/Mesh/MeshSpec.swift`:

```swift
/// 메시 그라디언트를 구성하는 색 하나의 배치 정보.
/// 좌표는 0...1 정규화 값이며 렌더러가 실제 크기로 환산한다.
public struct MeshBlob: Equatable, Sendable {
    public let colorIndex: Int
    public let weight: Double
    public let centerX: Double
    public let centerY: Double
    /// 번짐 반경 (정규화)
    public let spread: Double
    /// 0...1
    public let alpha: Double

    public init(colorIndex: Int, weight: Double,
                centerX: Double, centerY: Double,
                spread: Double, alpha: Double) {
        self.colorIndex = colorIndex
        self.weight = weight
        self.centerX = centerX
        self.centerY = centerY
        self.spread = spread
        self.alpha = alpha
    }
}

/// 한 지역의 색 표현. 블롭이 비어 있으면 아직 캔버스가 없는 지역이다.
public struct MeshSpec: Equatable, Sendable {
    /// 색인덱스 오름차순
    public let blobs: [MeshBlob]

    public var isEmpty: Bool { blobs.isEmpty }

    public init(blobs: [MeshBlob]) {
        self.blobs = blobs
    }
}
```

`Sources/MoeumCore/Mesh/MeshComposer.swift`:

```swift
import Foundation

/// 지역코드와 캔버스 색 배열로 메시 배치를 만든다. 스펙 3.2절 3~4단계.
public enum MeshComposer {

    /// 중심에서 블롭까지의 거리 범위
    static let minDistance = 0.28
    static let distanceRange = 0.22
    /// 번짐 = base + weight * scale
    static let spreadBase = 0.55
    static let spreadScale = 0.75
    /// 진하기 = base + weight * scale
    static let alphaBase = 0.55
    static let alphaScale = 0.45
    /// 색인덱스별 난수 스트림을 갈라놓는 상수 (Knuth 황금비 해시)
    static let colorSalt: UInt64 = 2_654_435_761

    public static func compose(regionCode: String, colorIndices: [Int]) -> MeshSpec {
        let weights = ColorTally.weights(from: colorIndices)
        guard !weights.isEmpty else { return MeshSpec(blobs: []) }

        let regionSeed = RegionHash.seed(for: regionCode)

        let blobs = weights.map { entry -> MeshBlob in
            // 위치는 (지역코드, 색인덱스)로만 결정된다.
            // 캔버스 개수가 바뀌어도 좌표가 움직이지 않는 이유가 여기다.
            var rng = SeededRandom(seed: regionSeed ^ (UInt64(entry.colorIndex) &* colorSalt))
            let angle = rng.next() * 2.0 * Double.pi
            let distance = minDistance + rng.next() * distanceRange

            return MeshBlob(
                colorIndex: entry.colorIndex,
                weight: entry.weight,
                centerX: 0.5 + distance * cos(angle),
                centerY: 0.5 + distance * sin(angle),
                spread: spreadBase + entry.weight * spreadScale,
                alpha: alphaBase + entry.weight * alphaScale
            )
        }

        return MeshSpec(blobs: blobs)
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

```bash
swift test --filter MeshComposerTests
```

기대: 11개 테스트 모두 PASS

- [ ] **Step 5: 커밋한다**

```bash
git add Sources/MoeumCore/Mesh/MeshSpec.swift Sources/MoeumCore/Mesh/MeshComposer.swift Tests/MoeumCoreTests/MeshComposerTests.swift
git commit -m "feat: 지역코드 시드 기반 메시 스펙 생성"
```

---

### Task 6: 작은 UI용 축약 표현

**Files:**
- Modify: `Sources/MoeumCore/Mesh/MeshSpec.swift` (파일 끝에 추가)
- Test: `Tests/MoeumCoreTests/MeshRepresentationTests.swift`

**Interfaces:**
- Consumes: `MeshSpec`, `MeshBlob` (Task 5)
- Produces: `LinearFallback(startColorIndex: Int, endColorIndex: Int)`, `MeshRepresentation.empty` / `.linear(LinearFallback)` / `.mesh(MeshSpec)`, `MeshSpec.compactThreshold: Double`, `MeshSpec.representation(shortestSide: Double) -> MeshRepresentation`

6겹 그라디언트를 12pt 점에 그리면 뭉개져서 단색만 못하다. 짧은 변이 임계 이하이면 상위 2색 선형으로 떨어뜨린다. **별도 규칙이 아니라 같은 데이터의 저해상도 표현**이므로 `MeshSpec`의 메서드로 둔다.

- [ ] **Step 1: 실패하는 테스트를 작성한다**

`Tests/MoeumCoreTests/MeshRepresentationTests.swift`:

```swift
import XCTest
@testable import MoeumCore

final class MeshRepresentationTests: XCTestCase {

    private let seongdong = "1120000000"

    func test_캔버스가_없으면_크기와_무관하게_empty다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [])
        XCTAssertEqual(spec.representation(shortestSide: 200), .empty)
        XCTAssertEqual(spec.representation(shortestSide: 12), .empty)
    }

    func test_임계값_초과면_메시를_그대로_쓴다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [5, 1])
        XCTAssertEqual(spec.representation(shortestSide: 98), .mesh(spec))
    }

    func test_임계값_이하면_선형으로_축약한다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [5, 5, 5, 1])
        XCTAssertEqual(
            spec.representation(shortestSide: 20),
            .linear(LinearFallback(startColorIndex: 5, endColorIndex: 1))
        )
    }

    func test_축약은_비중_큰_색이_앞에_온다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [1, 5, 5, 5, 9])
        guard case .linear(let fallback) = spec.representation(shortestSide: 16) else {
            return XCTFail("선형 축약이 나와야 합니다")
        }
        XCTAssertEqual(fallback.startColorIndex, 5)
    }

    func test_단색은_시작과_끝이_같다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [5])
        XCTAssertEqual(
            spec.representation(shortestSide: 10),
            .linear(LinearFallback(startColorIndex: 5, endColorIndex: 5))
        )
    }

    func test_임계값_경계는_이하가_선형이다() {
        let spec = MeshComposer.compose(regionCode: seongdong, colorIndices: [5, 1])
        guard case .linear = spec.representation(shortestSide: MeshSpec.compactThreshold) else {
            return XCTFail("임계값과 같으면 선형이어야 합니다")
        }
        guard case .mesh = spec.representation(shortestSide: MeshSpec.compactThreshold + 0.1) else {
            return XCTFail("임계값을 넘으면 메시여야 합니다")
        }
    }

    func test_임계값은_20이다() {
        XCTAssertEqual(MeshSpec.compactThreshold, 20.0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

```bash
swift test --filter MeshRepresentationTests
```

기대: 컴파일 실패. `cannot find 'LinearFallback' in scope`

- [ ] **Step 3: 최소 구현을 작성한다**

`Sources/MoeumCore/Mesh/MeshSpec.swift` 파일 끝에 추가:

```swift
/// 작은 영역에서 쓰는 2색 선형 축약.
public struct LinearFallback: Equatable, Sendable {
    /// 비중이 가장 큰 색
    public let startColorIndex: Int
    /// 두 번째 색. 색이 하나뿐이면 start와 같다.
    public let endColorIndex: Int

    public init(startColorIndex: Int, endColorIndex: Int) {
        self.startColorIndex = startColorIndex
        self.endColorIndex = endColorIndex
    }
}

/// 렌더러가 실제로 그릴 형태. 크기에 따라 결정된다.
public enum MeshRepresentation: Equatable, Sendable {
    case empty
    case linear(LinearFallback)
    case mesh(MeshSpec)
}

public extension MeshSpec {

    /// 짧은 변이 이 값 이하이면 선형으로 축약한다.
    static let compactThreshold = 20.0

    func representation(shortestSide: Double) -> MeshRepresentation {
        guard !isEmpty else { return .empty }
        guard shortestSide <= Self.compactThreshold else { return .mesh(self) }

        // 비중 내림차순, 동점이면 색인덱스 오름차순.
        let ranked = blobs.sorted { lhs, rhs in
            lhs.weight == rhs.weight ? lhs.colorIndex < rhs.colorIndex : lhs.weight > rhs.weight
        }
        let start = ranked[0].colorIndex
        let end = ranked.count > 1 ? ranked[1].colorIndex : start
        return .linear(LinearFallback(startColorIndex: start, endColorIndex: end))
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

```bash
swift test --filter MeshRepresentationTests
```

기대: 7개 테스트 모두 PASS

- [ ] **Step 5: 커밋한다**

```bash
git add Sources/MoeumCore/Mesh/MeshSpec.swift Tests/MoeumCoreTests/MeshRepresentationTests.swift
git commit -m "feat: 작은 영역용 2색 선형 축약 표현"
```

---

### Task 7: 통계 계산

**Files:**
- Create: `Sources/MoeumCore/Stats/CanvasSummary.swift`
- Create: `Sources/MoeumCore/Stats/StatsCalculator.swift`
- Test: `Tests/MoeumCoreTests/StatsCalculatorTests.swift`

**Interfaces:**
- Consumes: `RegionCatalog` (Task 3), `PastelPalette.count` (Task 1)
- Produces: `CanvasSummary(regionCode: String, colorIndex: Int, createdAt: Date)`, `CollectionStats(totalCanvases:coloredDistricts:totalDistricts:completedCollectBooks:colorDistribution:currentStreakDays:)`, `StatsCalculator.compute(canvases:catalog:calendar:today:) -> CollectionStats`

스펙 9.1절 표의 6개 지표를 그대로 구현한다. **`Date()`와 `Calendar.current`를 함수 안에서 부르지 않고 인자로 받는다** — 그래야 테스트가 시간과 타임존에 흔들리지 않는다.

- [ ] **Step 1: 실패하는 테스트를 작성한다**

`Tests/MoeumCoreTests/StatsCalculatorTests.swift`:

```swift
import XCTest
@testable import MoeumCore

final class StatsCalculatorTests: XCTestCase {

    private let csv = """
    code,name,parentCode,level
    1100000000,서울특별시,,province
    1120000000,성동구,1100000000,district
    1144000000,마포구,1100000000,district
    2600000000,부산광역시,,province
    2611000000,중구,2600000000,district
    """

    private var catalog: RegionCatalog!
    private var calendar: Calendar!
    private var today: Date!

    override func setUpWithError() throws {
        catalog = try RegionCatalog(csv: csv)
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "Asia/Seoul")!
        calendar = gregorian
        today = calendar.date(from: DateComponents(year: 2026, month: 7, day: 31))!
    }

    private func daysAgo(_ count: Int) -> Date {
        calendar.date(byAdding: .day, value: -count, to: today)!
    }

    private func canvas(_ regionCode: String, _ colorIndex: Int, _ date: Date) -> CanvasSummary {
        CanvasSummary(regionCode: regionCode, colorIndex: colorIndex, createdAt: date)
    }

    func test_캔버스가_없으면_전부_0이다() {
        let stats = StatsCalculator.compute(canvases: [], catalog: catalog,
                                            calendar: calendar, today: today)
        XCTAssertEqual(stats.totalCanvases, 0)
        XCTAssertEqual(stats.coloredDistricts, 0)
        XCTAssertEqual(stats.completedCollectBooks, 0)
        XCTAssertEqual(stats.currentStreakDays, 0)
        XCTAssertEqual(stats.colorDistribution, [Int](repeating: 0, count: 12))
    }

    func test_전체_시군구_수는_카탈로그를_따른다() {
        let stats = StatsCalculator.compute(canvases: [], catalog: catalog,
                                            calendar: calendar, today: today)
        XCTAssertEqual(stats.totalDistricts, 3)
    }

    func test_물들인_지역은_중복을_세지_않는다() {
        let stats = StatsCalculator.compute(
            canvases: [canvas("1120000000", 5, today),
                       canvas("1120000000", 1, today),
                       canvas("2611000000", 9, today)],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.totalCanvases, 3)
        XCTAssertEqual(stats.coloredDistricts, 2)
    }

    func test_하위_시군구가_모두_채워져야_콜렉트북_완성이다() {
        // 부산은 중구 하나뿐이라 1장으로 완성. 서울은 2개 중 1개뿐이라 미완성.
        let stats = StatsCalculator.compute(
            canvases: [canvas("1120000000", 5, today),
                       canvas("2611000000", 9, today)],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.completedCollectBooks, 1)
    }

    func test_서울을_다_채우면_완성이_둘이_된다() {
        let stats = StatsCalculator.compute(
            canvases: [canvas("1120000000", 5, today),
                       canvas("1144000000", 5, today),
                       canvas("2611000000", 9, today)],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.completedCollectBooks, 2)
    }

    func test_색_분포는_12칸_배열이다() {
        let stats = StatsCalculator.compute(
            canvases: [canvas("1120000000", 5, today),
                       canvas("1120000000", 5, today),
                       canvas("1144000000", 0, today)],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.colorDistribution.count, 12)
        XCTAssertEqual(stats.colorDistribution[5], 2)
        XCTAssertEqual(stats.colorDistribution[0], 1)
        XCTAssertEqual(stats.colorDistribution[9], 0)
    }

    func test_카탈로그에_없는_지역은_집계에서_제외한다() {
        let stats = StatsCalculator.compute(
            canvases: [canvas("9999000000", 5, today)],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.totalCanvases, 1)
        XCTAssertEqual(stats.coloredDistricts, 0)
    }

    func test_오늘부터_연속이면_스트릭이_쌓인다() {
        let stats = StatsCalculator.compute(
            canvases: [canvas("1120000000", 5, today),
                       canvas("1120000000", 5, daysAgo(1)),
                       canvas("1120000000", 5, daysAgo(2))],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.currentStreakDays, 3)
    }

    func test_같은_날_여러_장은_하루로_센다() {
        let stats = StatsCalculator.compute(
            canvases: [canvas("1120000000", 5, today),
                       canvas("1144000000", 1, today)],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.currentStreakDays, 1)
    }

    func test_오늘_안_썼어도_어제까지_연속이면_유지된다() {
        let stats = StatsCalculator.compute(
            canvases: [canvas("1120000000", 5, daysAgo(1)),
                       canvas("1120000000", 5, daysAgo(2))],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.currentStreakDays, 2)
    }

    func test_이틀_이상_비면_스트릭이_끊긴다() {
        let stats = StatsCalculator.compute(
            canvases: [canvas("1120000000", 5, daysAgo(2)),
                       canvas("1120000000", 5, daysAgo(3))],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.currentStreakDays, 0)
    }

    func test_중간에_빈_날이_있으면_거기서_멈춘다() {
        let stats = StatsCalculator.compute(
            canvases: [canvas("1120000000", 5, today),
                       canvas("1120000000", 5, daysAgo(1)),
                       canvas("1120000000", 5, daysAgo(3))],
            catalog: catalog, calendar: calendar, today: today)
        XCTAssertEqual(stats.currentStreakDays, 2)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

```bash
swift test --filter StatsCalculatorTests
```

기대: 컴파일 실패. `cannot find 'StatsCalculator' in scope`

- [ ] **Step 3: 최소 구현을 작성한다**

`Sources/MoeumCore/Stats/CanvasSummary.swift`:

```swift
import Foundation

/// 통계 계산에 필요한 캔버스 최소 정보. 저장 계층과 분리하기 위한 값 타입이다.
public struct CanvasSummary: Equatable, Sendable {
    public let regionCode: String
    public let colorIndex: Int
    public let createdAt: Date

    public init(regionCode: String, colorIndex: Int, createdAt: Date) {
        self.regionCode = regionCode
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }
}
```

`Sources/MoeumCore/Stats/StatsCalculator.swift`:

```swift
import Foundation

/// 스펙 9.1절 통계 6종.
public struct CollectionStats: Equatable, Sendable {
    public let totalCanvases: Int
    /// 캔버스가 1장 이상인 시·군·구 수
    public let coloredDistricts: Int
    public let totalDistricts: Int
    /// 하위 시·군·구가 모두 1장 이상인 시·도 수
    public let completedCollectBooks: Int
    /// 12칸. 각 색의 캔버스 개수
    public let colorDistribution: [Int]
    public let currentStreakDays: Int

    public init(totalCanvases: Int, coloredDistricts: Int, totalDistricts: Int,
                completedCollectBooks: Int, colorDistribution: [Int], currentStreakDays: Int) {
        self.totalCanvases = totalCanvases
        self.coloredDistricts = coloredDistricts
        self.totalDistricts = totalDistricts
        self.completedCollectBooks = completedCollectBooks
        self.colorDistribution = colorDistribution
        self.currentStreakDays = currentStreakDays
    }
}

public enum StatsCalculator {

    /// `calendar`와 `today`를 인자로 받는 이유는 테스트가 실제 시각·타임존에 흔들리지 않게 하기 위함이다.
    public static func compute(canvases: [CanvasSummary],
                               catalog: RegionCatalog,
                               calendar: Calendar,
                               today: Date) -> CollectionStats {

        var distribution = [Int](repeating: 0, count: PastelPalette.count)
        var filledDistricts = Set<String>()
        var recordedDays = Set<Date>()

        for canvas in canvases {
            let normalized = ((canvas.colorIndex % PastelPalette.count) + PastelPalette.count)
                % PastelPalette.count
            distribution[normalized] += 1
            recordedDays.insert(calendar.startOfDay(for: canvas.createdAt))
            if catalog.region(code: canvas.regionCode)?.level == .district {
                filledDistricts.insert(canvas.regionCode)
            }
        }

        let completed = catalog.provinces.filter { province in
            let districts = catalog.districts(of: province.code)
            return !districts.isEmpty && districts.allSatisfy { filledDistricts.contains($0.code) }
        }.count

        return CollectionStats(
            totalCanvases: canvases.count,
            coloredDistricts: filledDistricts.count,
            totalDistricts: catalog.districtCount,
            completedCollectBooks: completed,
            colorDistribution: distribution,
            currentStreakDays: streak(days: recordedDays, calendar: calendar, today: today)
        )
    }

    /// 오늘 기록이 있으면 오늘부터, 없고 어제 있으면 어제부터 거슬러 세다가 빈 날에서 멈춘다.
    private static func streak(days: Set<Date>, calendar: Calendar, today: Date) -> Int {
        let startOfToday = calendar.startOfDay(for: today)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return 0
        }

        var cursor: Date
        if days.contains(startOfToday) {
            cursor = startOfToday
        } else if days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }
}
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

```bash
swift test --filter StatsCalculatorTests
```

기대: 12개 테스트 모두 PASS

- [ ] **Step 5: 전체 테스트를 돌려 회귀가 없는지 확인한다**

```bash
swift test
```

기대: 7개 테스트 클래스 전부 PASS (총 69개 테스트 — 팔레트 5, 난수 6, 카탈로그 16, 집계 12, 메시 11, 축약 7, 통계 12)

- [ ] **Step 6: 커밋한다**

```bash
git add Sources/MoeumCore/Stats Tests/MoeumCoreTests/StatsCalculatorTests.swift
git commit -m "feat: 수집 통계 6종 계산"
```

---

## 이 계획을 끝내면 갖게 되는 것

- `swift test` 한 줄로 전 로직이 검증되는 `MoeumCore` 패키지
- 후속 계획(데이터 레이어·에디터·화면)이 소비할 확정된 인터페이스
- 스펙 15절 테스트 항목 중 **색 혼합 결정론, 위치 불변성, 상위 6색 절단·흡수, `regionCode`↔`provinceCode` 일관성** 4개가 이 시점에 이미 통과 상태

## 후속 계획 (별도 문서, macOS + Xcode 필요)

| # | 계획 | 범위 |
|---|---|---|
| 2 | 데이터 레이어 | `Canvas`·`CanvasPhoto`·`ShelfPreference` SwiftData 모델, CloudKit 동기화, 로컬 모드 격하, 백업 zip |
| 3 | 에디터 | 레이어 4종, 제스처·역회전 행렬, Undo, 임시저장, 투명도·톤 필터·배경 틴트·누끼, 익스포트 |
| 4 | 화면 | 책장(순서 편집)·콜렉트북·지역·생성 마법사 3스텝·뷰어·통합 검색. **MeshSpec을 SwiftUI로 렌더하는 어댑터 포함** |
| 5 | 부가 | 내 정보·통계 화면·설정 4종·로컬 알림 4종·Face ID 잠금 |

**스파이크 S1(메시 그라디언트 렌더 성능)은 계획 4의 첫 태스크**가 되어야 한다. 이 계획이 내놓는 `MeshSpec`을 실제 SwiftUI로 그려봐야 검증되기 때문이다. S1이 깨지면 스펙 3절 색 표현 규칙을 재검토해야 하므로, 계획 4를 쓰기 전에 스파이크만 먼저 돌리는 것을 권한다.
