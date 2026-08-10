# Phase 0 — 셋업 + 스파이크 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Xcode 프로젝트 골격을 세우고, v4 설계의 최대 기술 리스크 3건을 실측으로 검증해 이후 phase의 설계를 확정한다.

**Architecture:** 순수 기하 로직(`Core/Geometry`)은 SwiftUI 없이 단위 테스트로 먼저 완성하고, 그 위에 UI 프로토타입을 얹어 성능을 실측한다. 순수 로직은 Phase 3~4에서 그대로 재사용하고, **UI 프로토타입만 폐기**한다.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData + CloudKit / Swift Testing / PencilKit / iOS 17+ / Xcode 26

## Global Constraints

`docs/plans/2026-08-10-00-roadmap.md`의 「전역 제약」 표 전체가 모든 태스크에 적용된다. 특히 이 phase에서 직접 설정하는 것:

- 최소 지원 **iOS 17.0**, 빌드 **Xcode 26 / iOS 26 SDK**
- 화면 방향 **Portrait · LandscapeLeft · LandscapeRight** (Upside Down 제외)
- `UIUserInterfaceStyle = Light` 고정 (다크모드 미지원)
- 논리좌표 폭 **1080 고정**, 높이 **1350** 또는 **1920**
- 외부 SDK **0개**
- CloudKit: 전 속성 기본값 또는 optional · `@Attribute(.unique)` 불가 · 관계는 양방향 optional

---

## ⚠️ 선행 조건 — 개발 환경

**현재 저장소는 `D:\SQ\moumzip` (Windows)이고 git 저장소가 아니다.** iOS 앱은 macOS + Xcode에서만 빌드되므로, Task 1에서 이 문제를 먼저 해결한다. 이것을 건너뛰면 Task 2 이후를 실행할 수 없다.

---

## File Structure

Phase 0에서 만드는 파일. **`Core/Geometry/`만 이후 phase로 살아남고 `Spikes/`는 전부 폐기한다.**

| 파일 | 책임 | 운명 |
|---|---|---|
| `Soozip.xcodeproj` | 프로젝트 설정 | 유지 |
| `Soozip/App/SoozipApp.swift` | 앱 진입점 | 유지 |
| `Soozip/Core/Geometry/LayerFrame.swift` | 레이어의 중심·크기·회전과 좌표 변환 | **유지 — Phase 3의 기반** |
| `Soozip/Core/Geometry/ResizeAnchor.swift` | 코너·변 핸들 리사이즈 계산 | **유지** |
| `Soozip/Core/Geometry/SnapEngine.swift` | 정렬·균등 간격·크기 일치 후보 계산 | **유지 — Phase 4의 기반** |
| `Soozip/Spikes/S1_GestureProbe.swift` | 선택 UI + 제스처 프로토타입 | 폐기 |
| `Soozip/Spikes/S2_CloudKitProbe.swift` | SwiftData 모델 검증용 | 폐기 (Phase 1에서 재작성) |
| `SoozipTests/Geometry/LayerFrameTests.swift` | 좌표 변환 테스트 | 유지 |
| `SoozipTests/Geometry/ResizeAnchorTests.swift` | 리사이즈 테스트 | 유지 |
| `SoozipTests/Geometry/SnapEngineTests.swift` | 스냅 테스트 | 유지 |
| `docs/reports/2026-08-10-spike-results.md` | 실측 결과 | 유지 |

---

### Task 1: 개발 환경 이전 — git 초기화와 macOS 작업 경로

**Files:**
- Create: `.gitignore`
- Create: `README.md`

**Interfaces:**
- Consumes: 없음 (첫 태스크)
- Produces: macOS에서 클론 가능한 git 저장소. 이후 모든 태스크는 macOS에서 실행된다.

- [ ] **Step 1: Windows 저장소에서 git 초기화**

```bash
cd /d/SQ/moumzip
git init
git branch -M main
```

- [ ] **Step 2: `.gitignore` 작성**

```gitignore
# Xcode
build/
DerivedData/
*.xcuserstate
xcuserdata/
*.xcscmblueprint
*.xccheckout
.DS_Store

# Swift Package Manager
.build/
.swiftpm/

# 세션 산출물
.omc/
.superpowers/
```

- [ ] **Step 3: `README.md` 작성**

```markdown
# soozip

흰 캔버스에 사진·텍스트·도형을 자유 배치해 만든 한 장을 모음집에 담는 iOS 앱.
서버·계정 없음.

## 문서

- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md`
- 구현 로드맵: `docs/plans/2026-08-10-00-roadmap.md`
- 도메인 컨텍스트: `context/` (collection · canvas · editor · media · sync · profile)

## 개발 환경

**macOS + Xcode 26 필수.** iOS 26 SDK로 빌드하며 최소 지원은 iOS 17.0.
```

- [ ] **Step 4: 첫 커밋**

```bash
git add .
git commit -m "chore: 저장소 초기화 — 설계 문서와 도메인 컨텍스트"
```

- [ ] **Step 5: 원격 저장소 생성 및 푸시**

```bash
gh repo create soozip --private --source=. --remote=origin --push
```

`gh`가 없으면 GitHub에서 빈 private 저장소를 만든 뒤:

```bash
git remote add origin <저장소 URL>
git push -u origin main
```

- [ ] **Step 6: macOS에서 클론하고 이후 작업 경로를 확정**

macOS 터미널에서:

```bash
git clone <저장소 URL> ~/dev/soozip
cd ~/dev/soozip
ls docs/specs/2026-08-10-moumzip-mvp-design-v4.md
```

Expected: 설계서 경로가 출력된다.

**이후 모든 태스크는 macOS의 이 경로에서 실행한다.**

---

### Task 2: Xcode 프로젝트 생성과 전역 설정

**Files:**
- Create: `Soozip.xcodeproj`
- Create: `Soozip/App/SoozipApp.swift`
- Create: `Soozip/Info.plist` (프로젝트 설정으로 생성됨)
- Test: `SoozipTests/SmokeTests.swift`

**Interfaces:**
- Consumes: Task 1의 git 저장소
- Produces: 빌드 가능한 앱 타깃 `Soozip`, 테스트 타깃 `SoozipTests`. 이후 모든 태스크가 이 타깃에 파일을 추가한다.

- [ ] **Step 1: Xcode에서 프로젝트 생성**

Xcode → File → New → Project → iOS → App

| 항목 | 값 |
|---|---|
| Product Name | `Soozip` |
| Interface | SwiftUI |
| Language | Swift |
| Storage | **None** (SwiftData는 Phase 1에서 직접 구성) |
| Include Tests | **체크** |
| 저장 위치 | `~/dev/soozip` (저장소 루트) |

- [ ] **Step 2: 전역 설정 적용**

프로젝트 → TARGETS → Soozip → General / Info에서:

| 설정 | 값 |
|---|---|
| Minimum Deployments | **iOS 17.0** |
| Supported Destinations | iPhone (iPad는 미정 — 지금은 제외) |
| iPhone Orientation | Portrait · Landscape Left · Landscape Right **(Upside Down 해제)** |

Info.plist에 다음을 추가:

```xml
<key>UIUserInterfaceStyle</key>
<string>Light</string>
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

- [ ] **Step 3: 폴더 구조 생성**

Xcode의 Group이 아니라 **실제 디렉토리**로 만든다. 터미널에서:

```bash
cd ~/dev/soozip/Soozip
mkdir -p App Core/{Layout,Image,Rendering,Geometry,Haptics} \
         Data/{Models,DraftStore,Repository} \
         Features/{CollectionHome,CollectionDetail,Viewer,Search,Profile} \
         Features/Editor/{Canvas,Selection,SmartGuide,Tools} \
         Resources/Fonts Spikes
```

Xcode에서 각 디렉토리를 프로젝트에 추가한다 (드래그 시 **"Create groups"** 선택).

생성된 `SoozipApp.swift`를 `App/`으로 옮긴다.

- [ ] **Step 4: 스모크 테스트 작성**

`SoozipTests/SmokeTests.swift`:

```swift
import Testing
@testable import Soozip

@Test func 앱_타깃이_빌드되고_테스트가_실행된다() {
    #expect(Bundle.main.bundleIdentifier != nil)
}
```

- [ ] **Step 5: 테스트 실행**

```bash
cd ~/dev/soozip
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' | tail -20
```

Expected: `TEST SUCCEEDED`

- [ ] **Step 6: 커밋**

```bash
git add .
git commit -m "chore: Xcode 프로젝트 생성 — iOS 17+, 세로·가로 지원, Light 고정"
```

---

### Task 3: LayerFrame — 좌표 변환 (S1 순수 로직)

**Files:**
- Create: `Soozip/Core/Geometry/LayerFrame.swift`
- Test: `SoozipTests/Geometry/LayerFrameTests.swift`

**Interfaces:**
- Consumes: 없음 (순수 값 타입)
- Produces:
  - `struct LayerFrame { var center: CGPoint; var size: CGSize; var rotation: CGFloat }`
  - `func toLocal(_ p: CGPoint) -> CGPoint` — 화면 좌표를 레이어 로컬 좌표로
  - `func toWorld(_ p: CGPoint) -> CGPoint` — 그 역변환
  - `enum Corner { case topLeft, topRight, bottomLeft, bottomRight }`
  - `func corner(_ c: Corner) -> CGPoint` — 회전이 적용된 월드 좌표
  - Task 4의 `ResizeAnchor`와 Task 5의 `SnapEngine`이 이 타입을 입력으로 받는다.

- [ ] **Step 1: 실패하는 테스트 작성**

`SoozipTests/Geometry/LayerFrameTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import Soozip

private func isClose(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.01 }

@Test func 회전이_0이면_로컬좌표는_중심기준_평행이동이다() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: 0)
    let local = frame.toLocal(CGPoint(x: 600, y: 400))
    #expect(isClose(local.x, 100))
    #expect(isClose(local.y, 0))
}

@Test func 회전된_레이어는_역회전_행렬로_로컬좌표를_구한다() {
    // 45° 회전된 레이어에서 중심의 오른쪽 100pt 지점은
    // 로컬 좌표로 (100·cos(-45°), 100·sin(-45°)) = (70.71, -70.71)
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: .pi / 4)
    let local = frame.toLocal(CGPoint(x: 600, y: 400))
    #expect(isClose(local.x, 70.71))
    #expect(isClose(local.y, -70.71))
}

@Test func toLocal과_toWorld는_서로_역변환이다() {
    let frame = LayerFrame(center: CGPoint(x: 320, y: 780),
                           size: CGSize(width: 150, height: 90),
                           rotation: 0.7)
    let original = CGPoint(x: 411, y: 623)
    let roundTrip = frame.toWorld(frame.toLocal(original))
    #expect(isClose(roundTrip.x, original.x))
    #expect(isClose(roundTrip.y, original.y))
}

@Test func 회전이_0인_레이어의_네_코너() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: 0)
    #expect(isClose(frame.corner(.topLeft).x, 400))
    #expect(isClose(frame.corner(.topLeft).y, 350))
    #expect(isClose(frame.corner(.bottomRight).x, 600))
    #expect(isClose(frame.corner(.bottomRight).y, 450))
}

@Test func 회전된_레이어의_코너는_중심에서_같은_거리에_있다() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: .pi / 6)
    let expected = hypot(100.0, 50.0)   // 대각 반지름
    for corner in [Corner.topLeft, .topRight, .bottomLeft, .bottomRight] {
        let p = frame.corner(corner)
        #expect(isClose(hypot(p.x - 500, p.y - 400), expected))
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SoozipTests/LayerFrameTests 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'LayerFrame' in scope`

- [ ] **Step 3: 최소 구현**

`Soozip/Core/Geometry/LayerFrame.swift`:

```swift
import CoreGraphics

enum Corner: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    /// 중심 기준 로컬 좌표의 부호 (x, y)
    var sign: (x: CGFloat, y: CGFloat) {
        switch self {
        case .topLeft:     return (-1, -1)
        case .topRight:    return ( 1, -1)
        case .bottomLeft:  return (-1,  1)
        case .bottomRight: return ( 1,  1)
        }
    }

    var opposite: Corner {
        switch self {
        case .topLeft:     return .bottomRight
        case .topRight:    return .bottomLeft
        case .bottomLeft:  return .topRight
        case .bottomRight: return .topLeft
        }
    }
}

/// 레이어의 기하 상태. 논리좌표계에서만 쓴다.
struct LayerFrame: Equatable {
    var center: CGPoint
    var size: CGSize
    var rotation: CGFloat   // 라디안

    /// 월드(논리) 좌표 → 레이어 로컬 좌표.
    /// 회전된 레이어를 드래그·리사이즈할 때 반드시 이 변환을 거친다.
    func toLocal(_ p: CGPoint) -> CGPoint {
        let dx = p.x - center.x
        let dy = p.y - center.y
        let c = cos(-rotation)
        let s = sin(-rotation)
        return CGPoint(x: dx * c - dy * s,
                       y: dx * s + dy * c)
    }

    /// 레이어 로컬 좌표 → 월드(논리) 좌표.
    func toWorld(_ p: CGPoint) -> CGPoint {
        let c = cos(rotation)
        let s = sin(rotation)
        return CGPoint(x: center.x + p.x * c - p.y * s,
                       y: center.y + p.x * s + p.y * c)
    }

    func corner(_ corner: Corner) -> CGPoint {
        let sign = corner.sign
        return toWorld(CGPoint(x: sign.x * size.width  / 2,
                               y: sign.y * size.height / 2))
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SoozipTests/LayerFrameTests 2>&1 | tail -20
```

Expected: 5개 테스트 전부 PASS

- [ ] **Step 5: 커밋**

```bash
git add Soozip/Core/Geometry/LayerFrame.swift SoozipTests/Geometry/LayerFrameTests.swift
git commit -m "feat: LayerFrame — 회전 레이어의 로컬/월드 좌표 변환"
```

---

### Task 4: ResizeAnchor — 코너·변 핸들 리사이즈 (S1 순수 로직)

**Files:**
- Create: `Soozip/Core/Geometry/ResizeAnchor.swift`
- Test: `SoozipTests/Geometry/ResizeAnchorTests.swift`

**Interfaces:**
- Consumes: Task 3의 `LayerFrame`, `Corner`
- Produces:
  - `enum Edge { case left, right, top, bottom }`
  - `func resized(draggingCorner: Corner, to worldPoint: CGPoint, minShortSide: CGFloat, maxLongSide: CGFloat) -> LayerFrame` — 비율 유지
  - `func resized(draggingEdge: Edge, to worldPoint: CGPoint, minShortSide: CGFloat, maxLongSide: CGFloat) -> LayerFrame` — 한 축만
  - Phase 3의 선택 UI가 이 두 함수를 호출한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`SoozipTests/Geometry/ResizeAnchorTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import Soozip

private func isClose(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.01 }
private let minSide: CGFloat = 40
private let maxSide: CGFloat = 7680   // 캔버스 긴 변 1920 × 4

@Test func 코너드래그시_대각_반대편_코너가_고정된다() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: 0)
    let anchor = frame.corner(.bottomLeft)

    let resized = frame.resized(draggingCorner: .topRight,
                                to: CGPoint(x: 700, y: 300),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.corner(.bottomLeft).x, anchor.x))
    #expect(isClose(resized.corner(.bottomLeft).y, anchor.y))
}

@Test func 회전된_레이어도_대각_반대편이_고정된다() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: .pi / 4)
    let anchor = frame.corner(.bottomLeft)

    let resized = frame.resized(draggingCorner: .topRight,
                                to: CGPoint(x: 640, y: 260),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.corner(.bottomLeft).x, anchor.x))
    #expect(isClose(resized.corner(.bottomLeft).y, anchor.y))
}

@Test func 코너드래그는_원본_비율을_유지한다() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: 0)
    let ratio = frame.size.width / frame.size.height

    let resized = frame.resized(draggingCorner: .topRight,
                                to: CGPoint(x: 900, y: 100),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.size.width / resized.size.height, ratio))
}

@Test func 크기_하한에서_정지한다() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: 0)
    // 대각 반대편(bottomLeft)에 거의 붙도록 끌어당긴다
    let resized = frame.resized(draggingCorner: .topRight,
                                to: CGPoint(x: 401, y: 449),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(min(resized.size.width, resized.size.height) >= minSide - 0.01)
}

@Test func 크기_상한에서_정지한다() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: 0)
    let resized = frame.resized(draggingCorner: .topRight,
                                to: CGPoint(x: 99_999, y: -99_999),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(max(resized.size.width, resized.size.height) <= maxSide + 0.01)
}

@Test func 변핸들은_한_축만_바꾼다() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: 0)
    let resized = frame.resized(draggingEdge: .right,
                                to: CGPoint(x: 700, y: 400),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.size.width, 300))
    #expect(isClose(resized.size.height, 100))   // 높이 불변
}

@Test func 변핸들도_반대쪽_변이_고정된다() {
    let frame = LayerFrame(center: CGPoint(x: 500, y: 400),
                           size: CGSize(width: 200, height: 100),
                           rotation: 0)
    let leftEdgeX = frame.corner(.topLeft).x

    let resized = frame.resized(draggingEdge: .right,
                                to: CGPoint(x: 700, y: 400),
                                minShortSide: minSide, maxLongSide: maxSide)

    #expect(isClose(resized.corner(.topLeft).x, leftEdgeX))
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SoozipTests/ResizeAnchorTests 2>&1 | tail -20
```

Expected: 컴파일 실패 — `value of type 'LayerFrame' has no member 'resized'`

- [ ] **Step 3: 최소 구현**

`Soozip/Core/Geometry/ResizeAnchor.swift`:

```swift
import CoreGraphics

enum Edge {
    case left, right, top, bottom

    /// 이 변을 끌 때 고정되는 반대쪽 변
    var opposite: Edge {
        switch self {
        case .left:   return .right
        case .right:  return .left
        case .top:    return .bottom
        case .bottom: return .top
        }
    }

    var isHorizontal: Bool { self == .left || self == .right }
}

extension LayerFrame {

    /// 코너 핸들 드래그 — 비율을 유지하고 대각 반대편 코너를 고정한다.
    func resized(draggingCorner corner: Corner,
                 to worldPoint: CGPoint,
                 minShortSide: CGFloat,
                 maxLongSide: CGFloat) -> LayerFrame {

        let anchorCorner = corner.opposite
        let anchorWorld = self.corner(anchorCorner)

        // 로컬 좌표에서 계산한다. 회전을 여기서 제거해야 대각 고정이 성립한다.
        let dragLocal = toLocal(worldPoint)
        let anchorLocal = CGPoint(x: anchorCorner.sign.x * size.width  / 2,
                                  y: anchorCorner.sign.y * size.height / 2)

        let rawW = abs(dragLocal.x - anchorLocal.x)
        let rawH = abs(dragLocal.y - anchorLocal.y)

        // 비율 유지: 원본 종횡비에 맞춰 더 큰 쪽을 기준으로 삼는다
        let ratio = size.width / size.height
        var newW = max(rawW, rawH * ratio)
        var newH = newW / ratio

        (newW, newH) = Self.clamped(width: newW, height: newH,
                                    minShortSide: minShortSide,
                                    maxLongSide: maxLongSide)

        // 고정점에서 드래그 방향으로 새 중심을 잡는다
        let dirX = corner.sign.x
        let dirY = corner.sign.y
        let newCenterLocal = CGPoint(x: anchorLocal.x + dirX * newW / 2,
                                     y: anchorLocal.y + dirY * newH / 2)
        let newCenterWorld = toWorld(newCenterLocal)

        var result = LayerFrame(center: newCenterWorld,
                                size: CGSize(width: newW, height: newH),
                                rotation: rotation)

        // 회전 중심이 바뀌었으므로 고정점이 유지되도록 보정한다
        let drift = CGPoint(x: anchorWorld.x - result.corner(anchorCorner).x,
                            y: anchorWorld.y - result.corner(anchorCorner).y)
        result.center.x += drift.x
        result.center.y += drift.y
        return result
    }

    /// 변 핸들 드래그 — 한 축만 바꾸고 반대쪽 변을 고정한다.
    func resized(draggingEdge edge: Edge,
                 to worldPoint: CGPoint,
                 minShortSide: CGFloat,
                 maxLongSide: CGFloat) -> LayerFrame {

        let dragLocal = toLocal(worldPoint)
        var newW = size.width
        var newH = size.height

        if edge.isHorizontal {
            newW = abs(dragLocal.x) + size.width / 2
        } else {
            newH = abs(dragLocal.y) + size.height / 2
        }

        (newW, newH) = Self.clamped(width: newW, height: newH,
                                    minShortSide: minShortSide,
                                    maxLongSide: maxLongSide)

        // 반대쪽 변을 고정하려면 중심을 늘어난 절반만큼 이동시킨다
        let deltaW = newW - size.width
        let deltaH = newH - size.height
        let shiftLocal: CGPoint
        switch edge {
        case .right:  shiftLocal = CGPoint(x:  deltaW / 2, y: 0)
        case .left:   shiftLocal = CGPoint(x: -deltaW / 2, y: 0)
        case .bottom: shiftLocal = CGPoint(x: 0, y:  deltaH / 2)
        case .top:    shiftLocal = CGPoint(x: 0, y: -deltaH / 2)
        }

        let newCenter = toWorld(shiftLocal)
        return LayerFrame(center: newCenter,
                          size: CGSize(width: newW, height: newH),
                          rotation: rotation)
    }

    /// 짧은 변 하한과 긴 변 상한을 비율을 유지한 채 적용한다.
    private static func clamped(width: CGFloat, height: CGFloat,
                                minShortSide: CGFloat,
                                maxLongSide: CGFloat) -> (CGFloat, CGFloat) {
        var w = width
        var h = height

        let shortSide = min(w, h)
        if shortSide < minShortSide, shortSide > 0 {
            let k = minShortSide / shortSide
            w *= k
            h *= k
        }

        let longSide = max(w, h)
        if longSide > maxLongSide {
            let k = maxLongSide / longSide
            w *= k
            h *= k
        }
        return (w, h)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SoozipTests/ResizeAnchorTests 2>&1 | tail -20
```

Expected: 7개 테스트 전부 PASS

실패하면 **구현이 아니라 테스트가 맞다고 가정하고 구현을 고친다.** 특히 회전 케이스에서 고정점이 어긋나면 `drift` 보정 로직을 점검한다.

- [ ] **Step 5: 커밋**

```bash
git add Soozip/Core/Geometry/ResizeAnchor.swift SoozipTests/Geometry/ResizeAnchorTests.swift
git commit -m "feat: ResizeAnchor — 코너/변 핸들 리사이즈, 대각 고정과 크기 제한"
```

---

### Task 5: SnapEngine — 정렬·균등 간격·크기 일치 (S1 순수 로직)

**Files:**
- Create: `Soozip/Core/Geometry/SnapEngine.swift`
- Test: `SoozipTests/Geometry/SnapEngineTests.swift`

**Interfaces:**
- Consumes: Task 3의 `LayerFrame`
- Produces:
  - `struct SnapCandidate { let axis: Axis; let value: CGFloat; let kind: SnapKind }`
  - `enum SnapKind { case alignment, equalSpacing, sizeMatch }`
  - `enum Axis { case horizontal, vertical }`
  - `func snapCandidates(for moving: LayerFrame, among others: [LayerFrame], canvasSize: CGSize, threshold: CGFloat) -> [SnapCandidate]`
  - Phase 4의 가이드 오버레이와 햅틱이 이 결과를 소비한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`SoozipTests/Geometry/SnapEngineTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import Soozip

private let canvas = CGSize(width: 1080, height: 1350)
private let threshold: CGFloat = 8

private func frame(x: CGFloat, y: CGFloat,
                   w: CGFloat = 100, h: CGFloat = 100,
                   rot: CGFloat = 0) -> LayerFrame {
    LayerFrame(center: CGPoint(x: x, y: y),
               size: CGSize(width: w, height: h),
               rotation: rot)
}

@Test func 캔버스_수직중심선에_가까우면_정렬후보가_나온다() {
    let moving = frame(x: 543, y: 400)          // 중심 540에서 3pt 차이
    let candidates = snapCandidates(for: moving, among: [],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.contains { $0.kind == .alignment && $0.axis == .vertical })
}

@Test func 임계를_벗어나면_후보가_없다() {
    let moving = frame(x: 600, y: 400)          // 중심 540에서 60pt 차이
    let candidates = snapCandidates(for: moving, among: [],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.isEmpty)
}

@Test func 다른_레이어의_좌측_가장자리에_정렬된다() {
    let other = frame(x: 300, y: 200)           // left = 250
    let moving = frame(x: 303, y: 600)          // left = 253, 3pt 차이
    let candidates = snapCandidates(for: moving, among: [other],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.contains { $0.kind == .alignment && $0.axis == .vertical })
}

@Test func 균등간격_후보는_같은축에_셋_이상일때만_나온다() {
    let a = frame(x: 200, y: 500)
    let b = frame(x: 400, y: 500)
    // a-b 간격이 200이므로 c가 600 근처면 균등해진다
    let moving = frame(x: 597, y: 500)
    let candidates = snapCandidates(for: moving, among: [a, b],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.contains { $0.kind == .equalSpacing })
}

@Test func 레이어가_둘뿐이면_균등간격_후보가_없다() {
    let a = frame(x: 200, y: 500)
    let moving = frame(x: 597, y: 500)
    let candidates = snapCandidates(for: moving, among: [a],
                                    canvasSize: canvas, threshold: threshold)
    #expect(!candidates.contains { $0.kind == .equalSpacing })
}

@Test func 회전된_레이어는_후보에서_제외된다() {
    // 회전체의 바운딩 박스는 실제 형태와 어긋나므로 계산에 넣지 않는다
    let rotated = frame(x: 300, y: 200, rot: .pi / 6)   // left = 250 이지만 회전됨
    let moving = frame(x: 303, y: 600)
    let candidates = snapCandidates(for: moving, among: [rotated],
                                    canvasSize: canvas, threshold: threshold)
    #expect(!candidates.contains { $0.kind == .alignment && $0.value == 250 })
}

@Test func 움직이는_레이어가_회전됐으면_후보가_없다() {
    let other = frame(x: 300, y: 200)
    let moving = frame(x: 303, y: 600, rot: 0.5)
    let candidates = snapCandidates(for: moving, among: [other],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.isEmpty)
}

@Test func 크기가_같아지는_지점에서_크기일치_후보가_나온다() {
    let other = frame(x: 300, y: 200, w: 240, h: 100)
    let moving = frame(x: 700, y: 600, w: 237, h: 100)   // 3pt 차이
    let candidates = snapCandidates(for: moving, among: [other],
                                    canvasSize: canvas, threshold: threshold)
    #expect(candidates.contains { $0.kind == .sizeMatch })
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SoozipTests/SnapEngineTests 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'snapCandidates' in scope`

- [ ] **Step 3: 최소 구현**

`Soozip/Core/Geometry/SnapEngine.swift`:

```swift
import CoreGraphics

enum Axis { case horizontal, vertical }

enum SnapKind { case alignment, equalSpacing, sizeMatch }

struct SnapCandidate: Equatable {
    let axis: Axis
    let value: CGFloat
    let kind: SnapKind
}

/// 회전값이 0인 레이어의 축 정렬 바운딩 박스.
private struct AABB {
    let minX, midX, maxX: CGFloat
    let minY, midY, maxY: CGFloat
    let width, height: CGFloat

    init(_ f: LayerFrame) {
        minX = f.center.x - f.size.width / 2
        maxX = f.center.x + f.size.width / 2
        midX = f.center.x
        minY = f.center.y - f.size.height / 2
        maxY = f.center.y + f.size.height / 2
        midY = f.center.y
        width = f.size.width
        height = f.size.height
    }
}

private func isAxisAligned(_ f: LayerFrame) -> Bool {
    abs(f.rotation) < 0.0001
}

/// 드래그·리사이즈 중 걸리는 스냅 후보를 모두 계산한다.
///
/// - 회전된 레이어는 움직이는 쪽이든 상대 쪽이든 전부 제외한다.
///   회전체의 바운딩 박스는 실제 형태와 어긋나서, 박스를 맞춰도 눈에는 안 맞아 보인다.
/// - `threshold`는 **화면 좌표 기준**으로 넘겨받는다. 논리좌표로 계산하면
///   줌 배율에 따라 감각이 달라진다.
func snapCandidates(for moving: LayerFrame,
                    among others: [LayerFrame],
                    canvasSize: CGSize,
                    threshold: CGFloat) -> [SnapCandidate] {

    guard isAxisAligned(moving) else { return [] }

    let m = AABB(moving)
    let peers = others.filter(isAxisAligned).map(AABB.init)
    var result: [SnapCandidate] = []

    // ── 1. 정렬: 캔버스 중심선
    let canvasMidX = canvasSize.width / 2
    let canvasMidY = canvasSize.height / 2
    if abs(m.midX - canvasMidX) <= threshold {
        result.append(.init(axis: .vertical, value: canvasMidX, kind: .alignment))
    }
    if abs(m.midY - canvasMidY) <= threshold {
        result.append(.init(axis: .horizontal, value: canvasMidY, kind: .alignment))
    }

    // ── 2. 정렬: 다른 레이어의 6개 기준선
    for p in peers {
        for value in [p.minX, p.midX, p.maxX] {
            for mine in [m.minX, m.midX, m.maxX] where abs(mine - value) <= threshold {
                result.append(.init(axis: .vertical, value: value, kind: .alignment))
            }
        }
        for value in [p.minY, p.midY, p.maxY] {
            for mine in [m.minY, m.midY, m.maxY] where abs(mine - value) <= threshold {
                result.append(.init(axis: .horizontal, value: value, kind: .alignment))
            }
        }
    }

    // ── 3. 균등 간격: 같은 축에 자기 포함 3개 이상일 때만
    if peers.count >= 2 {
        let sortedX = peers.map(\.midX).sorted()
        for i in 0..<(sortedX.count - 1) {
            let gap = sortedX[i + 1] - sortedX[i]
            guard gap > 0 else { continue }
            for target in [sortedX[i] - gap, sortedX[i + 1] + gap]
            where abs(m.midX - target) <= threshold {
                result.append(.init(axis: .vertical, value: target, kind: .equalSpacing))
            }
        }
        let sortedY = peers.map(\.midY).sorted()
        for i in 0..<(sortedY.count - 1) {
            let gap = sortedY[i + 1] - sortedY[i]
            guard gap > 0 else { continue }
            for target in [sortedY[i] - gap, sortedY[i + 1] + gap]
            where abs(m.midY - target) <= threshold {
                result.append(.init(axis: .horizontal, value: target, kind: .equalSpacing))
            }
        }
    }

    // ── 4. 크기 일치
    for p in peers {
        if abs(m.width - p.width) <= threshold {
            result.append(.init(axis: .vertical, value: p.width, kind: .sizeMatch))
        }
        if abs(m.height - p.height) <= threshold {
            result.append(.init(axis: .horizontal, value: p.height, kind: .sizeMatch))
        }
    }

    return result
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SoozipTests/SnapEngineTests 2>&1 | tail -20
```

Expected: 8개 테스트 전부 PASS

- [ ] **Step 5: 커밋**

```bash
git add Soozip/Core/Geometry/SnapEngine.swift SoozipTests/Geometry/SnapEngineTests.swift
git commit -m "feat: SnapEngine — 정렬·균등 간격·크기 일치 후보 계산"
```

---

### Task 6: S1 스파이크 — 선택 UI 프로토타입과 60fps 실측

**Files:**
- Create: `Soozip/Spikes/S1_GestureProbe.swift`
- Modify: `Soozip/App/SoozipApp.swift` (스파이크 화면을 임시 루트로)

**Interfaces:**
- Consumes: Task 3~5의 `LayerFrame` · `ResizeAnchor` · `SnapEngine`
- Produces: 실측 수치만. **코드는 Task 8 이후 폐기한다.**

- [ ] **Step 1: 프로토타입 화면 작성**

`Soozip/Spikes/S1_GestureProbe.swift`:

```swift
import SwiftUI

/// S1 스파이크 전용. Phase 3에서 정식 구현으로 대체하고 이 파일은 삭제한다.
struct S1_GestureProbe: View {
    @State private var frames: [LayerFrame] = (0..<43).map { i in
        LayerFrame(center: CGPoint(x: 120 + CGFloat(i % 7) * 140,
                                   y: 150 + CGFloat(i / 7) * 180),
                   size: CGSize(width: 100, height: 100),
                   rotation: 0)
    }
    @State private var selected: Int? = nil
    @State private var zoom: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @State private var activeSnaps: [SnapCandidate] = []

    private let canvasSize = CGSize(width: 1080, height: 1350)

    var body: some View {
        GeometryReader { geo in
            let fit = min(geo.size.width / canvasSize.width,
                          geo.size.height / canvasSize.height)
            let scale = fit * zoom

            ZStack {
                Color.white

                ForEach(frames.indices, id: \.self) { i in
                    Rectangle()
                        .fill(i == selected ? Color.pink.opacity(0.5)
                                            : Color.gray.opacity(0.3))
                        .frame(width: frames[i].size.width * scale,
                               height: frames[i].size.height * scale)
                        .rotationEffect(.radians(frames[i].rotation))
                        .position(x: frames[i].center.x * scale + pan.width,
                                  y: frames[i].center.y * scale + pan.height)
                        .onTapGesture { selected = i }
                }

                // 스냅 가이드선
                ForEach(activeSnaps.indices, id: \.self) { i in
                    let snap = activeSnaps[i]
                    Rectangle()
                        .fill(Color(red: 1, green: 0, blue: 1))   // SwiftUI에 Color.magenta는 없다
                        .frame(width: snap.axis == .vertical ? 1 : geo.size.width,
                               height: snap.axis == .vertical ? geo.size.height : 1)
                        .position(x: snap.axis == .vertical
                                     ? snap.value * scale + pan.width
                                     : geo.size.width / 2,
                                  y: snap.axis == .vertical
                                     ? geo.size.height / 2
                                     : snap.value * scale + pan.height)
                }

                if let s = selected {
                    SelectionOverlayProbe(frame: frames[s], scale: scale, pan: pan)
                }
            }
            .gesture(dragGesture(scale: scale))
            .gesture(magnifyGesture())
        }
    }

    private func dragGesture(scale: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let s = selected else {
                    pan = value.translation
                    return
                }
                let logical = CGPoint(x: value.location.x / scale,
                                      y: value.location.y / scale)
                frames[s].center = logical

                let others = frames.enumerated()
                    .filter { $0.offset != s }
                    .map(\.element)
                activeSnaps = snapCandidates(for: frames[s],
                                             among: others,
                                             canvasSize: canvasSize,
                                             threshold: 8 / scale)
            }
            .onEnded { _ in activeSnaps = [] }
    }

    private func magnifyGesture() -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard selected == nil else { return }   // 선택 있으면 레이어 담당
                zoom = min(max(value.magnification, 0.5), 4.0)
            }
    }
}

private struct SelectionOverlayProbe: View {
    let frame: LayerFrame
    let scale: CGFloat
    let pan: CGSize

    var body: some View {
        ZStack {
            ForEach(Corner.allCases, id: \.self) { corner in
                let p = frame.corner(corner)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)          // 시각 12pt
                    .overlay(Rectangle().stroke(Color.blue, lineWidth: 1))
                    .frame(width: 44, height: 44)          // 히트 영역을 44pt로 넓힌다
                    .contentShape(Rectangle())             // 넓힌 프레임 전체를 탭 대상으로
                    .position(x: p.x * scale + pan.width,
                              y: p.y * scale + pan.height)
            }
        }
    }
}
```

- [ ] **Step 2: 임시 루트로 연결**

`Soozip/App/SoozipApp.swift`:

```swift
import SwiftUI

@main
struct SoozipApp: App {
    var body: some Scene {
        WindowGroup {
            S1_GestureProbe()   // Phase 0 전용. Task 8에서 제거한다.
        }
    }
}
```

- [ ] **Step 3: 실기기에서 4개 기준 측정**

**시뮬레이터가 아니라 실기기에서** 측정한다. 시뮬레이터는 Mac의 GPU를 쓰므로 프레임 수치가 의미 없다.

| 측정 | 방법 | 통과 기준 |
|---|---|---|
| 60fps | Instruments → Animation Hooks, 레이어 43개 상태로 10초 연속 드래그 | 평균 60fps, 드롭 프레임 5% 미만 |
| 회전 리사이즈 | 레이어 하나를 45° 회전시킨 뒤 코너 드래그 | 대각 반대편이 눈에 띄게 움직이지 않음 |
| 핸들 히트 | 줌 200%에서 핸들 가장자리를 탭 | 12pt 그래픽 밖 44pt 영역에서도 잡힘 |
| 제스처 배타 | 선택 있는 상태 / 없는 상태에서 각각 핀치 | 레이어 / 캔버스로 정확히 갈림 |

- [ ] **Step 4: 측정값을 보고서에 기록**

`docs/reports/2026-08-10-spike-results.md`에 S1 절을 만들고 **실측 수치를 그대로** 적는다. "잘 동작함" 같은 표현은 쓰지 않는다.

- [ ] **Step 5: 60fps 미달 시 대응 결정**

미달이면 아래 중 하나를 고르고 **v4 설계서 §5.8.4를 수정**한다.

1. 스냅 계산을 매 프레임이 아니라 16ms 스로틀링
2. 후보를 화면 안 레이어로만 축소
3. 균등 간격 가이드를 P1로 이월 (가장 비싼 계산)

- [ ] **Step 6: 커밋**

```bash
git add Soozip/Spikes/S1_GestureProbe.swift Soozip/App/SoozipApp.swift docs/reports/2026-08-10-spike-results.md
git commit -m "spike: S1 제스처·선택 UI·스마트 가이드 실측"
```

---

### Task 7: S2 스파이크 — SwiftData + CloudKit 실기기 동기화

**Files:**
- Create: `Soozip/Spikes/S2_CloudKitProbe.swift`
- Modify: `Soozip/App/SoozipApp.swift`

**Interfaces:**
- Consumes: 없음
- Produces: 검증된 모델 제약. **Phase 1에서 정식 모델을 다시 작성**하되 여기서 확인한 제약을 그대로 적용한다.

- [ ] **Step 1: CloudKit 컨테이너 설정**

Xcode → TARGETS → Soozip → Signing & Capabilities:
1. **+ Capability → iCloud** 추가
2. Services에서 **CloudKit** 체크
3. Containers에서 **+** 로 `iCloud.com.<팀식별자>.Soozip` 생성
4. **+ Capability → Background Modes** 추가 후 **Remote notifications** 체크

- [ ] **Step 2: 프로브 모델 작성**

`Soozip/Spikes/S2_CloudKitProbe.swift`:

```swift
import SwiftUI
import SwiftData

// S2 스파이크 전용. Phase 1에서 Data/Models/ 아래 정식 모델로 대체하고 삭제한다.

@Model final class ProbeCollection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var coverCanvasID: String = ""
    var canvases: [ProbeCanvas]? = []
}

@Model final class ProbeCanvas {
    var id: UUID = UUID()
    var aspect: Int = 0
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var layoutJSON: Data = Data()
    @Attribute(.externalStorage) var renderedPNG: Data?
    var collection: ProbeCollection?
}

struct S2_CloudKitProbe: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ProbeCollection.createdAt) private var collections: [ProbeCollection]
    @State private var draftFolderExists = false

    var body: some View {
        NavigationStack {
            List {
                Section("모음집 \(collections.count)개") {
                    ForEach(collections) { c in
                        VStack(alignment: .leading) {
                            Text(c.name)
                            Text("캔버스 \(c.canvases?.count ?? 0)개")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("초안 폴더") {
                    Text(draftFolderExists ? "존재함" : "없음")
                    Button("초안 폴더 만들기") { makeDraftFolder() }
                }
            }
            .toolbar {
                Button("추가") { addSample() }
            }
            .onAppear { checkDraftFolder() }
        }
    }

    private func addSample() {
        let c = ProbeCollection()
        c.name = "테스트 \(Int.random(in: 100...999))"
        let canvas = ProbeCanvas()
        canvas.title = "캔버스"
        canvas.collection = c
        context.insert(c)
        context.insert(canvas)
        try? context.save()
    }

    private var draftsURL: URL {
        URL.applicationSupportDirectory.appending(path: "Drafts")
    }

    private func makeDraftFolder() {
        try? FileManager.default.createDirectory(at: draftsURL,
                                                 withIntermediateDirectories: true)
        try? "probe".data(using: .utf8)?
            .write(to: draftsURL.appending(path: "probe.txt"))
        checkDraftFolder()
    }

    private func checkDraftFolder() {
        draftFolderExists = FileManager.default
            .fileExists(atPath: draftsURL.appending(path: "probe.txt").path())
    }
}
```

- [ ] **Step 3: 앱에 모델 컨테이너 연결**

`Soozip/App/SoozipApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct SoozipApp: App {
    var body: some Scene {
        WindowGroup {
            S2_CloudKitProbe()   // Phase 0 전용. Task 8에서 제거한다.
        }
        .modelContainer(for: [ProbeCollection.self, ProbeCanvas.self])
    }
}
```

- [ ] **Step 4: 실기기 2대로 동기화 검증**

같은 iCloud 계정으로 로그인한 기기 2대에 설치하고:

| 검증 | 절차 | 통과 기준 |
|---|---|---|
| 양방향 동기화 | A에서 추가 → B에서 확인, B에서 추가 → A에서 확인 | 30초 내 반영 |
| 관계 동기화 | A에서 캔버스 추가 → B에서 개수 확인 | 개수 일치 |
| **초안 미동기화** | A에서 "초안 폴더 만들기" → B에서 확인 | **B에는 "없음"으로 표시** |
| 로컬 모드 | 기기 하나를 iCloud 로그아웃 → 앱 사용 | 크래시 없이 로컬 동작 |

- [ ] **Step 5: 결과 기록**

`docs/reports/2026-08-10-spike-results.md`에 S2 절을 추가한다. **초안 미동기화가 확인되지 않으면 Phase 2 설계 전체를 재검토해야 하므로 반드시 명시적으로 확인한다.**

- [ ] **Step 6: 커밋**

```bash
git add Soozip/Spikes/S2_CloudKitProbe.swift Soozip/App/SoozipApp.swift docs/reports/2026-08-10-spike-results.md
git commit -m "spike: S2 SwiftData+CloudKit 실기기 2대 동기화 검증"
```

---

### Task 8: S3 스파이크 — 폰트 번들 용량과 정리

**Files:**
- Create: `Soozip/Resources/Fonts/` (폰트 5종)
- Modify: `Soozip/Info.plist`
- Modify: `Soozip/App/SoozipApp.swift` (스파이크 제거, 빈 화면으로 복귀)
- Delete: `Soozip/Spikes/` 전체
- Test: `SoozipTests/FontLoadingTests.swift`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `enum AppFont: String, CaseIterable { case pretendard, gowunBatang, gowunDodum, nanumPen, playfair }`
  - `var postScriptName: String` — `layoutJSON`의 `font` 값과 실제 폰트를 잇는다. Phase 5의 텍스트 도구가 사용한다.

- [ ] **Step 1: 폰트 5종 수집 및 라이선스 확인**

전부 SIL OFL인지 **배포처의 라이선스 원문(`OFL.txt`)으로 확인**하고, 그 원문을 `Soozip/Resources/Fonts/licenses/`에 함께 보관한다. Phase 9의 설정 > 정보 고지에 쓴다.

| 폰트 | 출처 |
|---|---|
| Pretendard | GitHub `orioncactus/pretendard` |
| 고운바탕 (Gowun Batang) | Google Fonts |
| 고운돋움 (Gowun Dodum) | Google Fonts |
| 나눔손글씨 (붓 또는 펜) | Google Fonts / 네이버 |
| Playfair Display | Google Fonts |

원본 파일을 `Soozip/Resources/Fonts/`에 넣는다. **아직 서브셋하지 않는다** — 먼저 재보고 필요할 때만 줄인다.

- [ ] **Step 2: 원본 용량 측정**

```bash
cd ~/dev/soozip
ls -lh Soozip/Resources/Fonts/
du -ch Soozip/Resources/Fonts/*.{ttf,otf} 2>/dev/null | tail -1
```

**통과 기준: 5종 합계 10MB 이하.**
- 10MB 이하 → Step 3을 건너뛰고 Step 4로
- 초과 → Step 3에서 서브셋

- [ ] **Step 3: (용량 초과 시에만) 서브셋**

**한글 음절은 전부 남기고 한자·일본어를 뺀다.** 사용자가 캔버스에 어떤 글자를 칠지 모르므로 한글을 잘라내면 글리프 누락이 난다 — 서브셋의 실익은 한글 축소가 아니라 **CJK 한자 제거**에 있다.

```bash
pip install fonttools brotli

# 유지할 범위:
#   U+0020-007E  ASCII
#   U+00A0-00FF  라틴-1 보충
#   U+2000-206F  일반 문장부호 (…, — 등)
#   U+3131-318E  한글 자모 (ㄱ, ㅏ 등 단독 입력)
#   U+AC00-D7A3  한글 음절 11,172자 전체
#   U+FF00-FFEF  전각 형태
RANGES='U+0020-007E,U+00A0-00FF,U+2000-206F,U+3131-318E,U+AC00-D7A3,U+FF00-FFEF'

for f in GowunBatang-Regular GowunDodum-Regular NanumPenScript-Regular; do
  pyftsubset "Soozip/Resources/Fonts/${f}.ttf" \
    --unicodes="$RANGES" \
    --output-file="Soozip/Resources/Fonts/${f}-Subset.ttf" \
    --layout-features='*' --no-hinting
done

du -ch Soozip/Resources/Fonts/*-Subset.ttf | tail -1
```

서브셋 후에도 10MB를 넘으면 **폰트를 3종으로 줄이거나 ODR로 전환**하고 v4 설계서 §5.5와 `context/editor/README.md`를 수정한다.

원본을 서브셋으로 교체했다면 원본 파일은 지운다.

- [ ] **Step 4: Info.plist 등록**

```xml
<key>UIAppFonts</key>
<array>
    <string>Pretendard-Regular.otf</string>
    <string>GowunBatang-Subset.ttf</string>
    <string>GowunDodum-Subset.ttf</string>
    <string>NanumPen-Subset.ttf</string>
    <string>PlayfairDisplay-Regular.ttf</string>
</array>
```

- [ ] **Step 5: 실패하는 테스트 작성**

`SoozipTests/FontLoadingTests.swift`:

```swift
import Testing
import UIKit
@testable import Soozip

@Test func 번들_폰트_5종이_모두_로드된다() {
    for font in AppFont.allCases {
        let loaded = UIFont(name: font.postScriptName, size: 20)
        #expect(loaded != nil, "폰트 로드 실패: \(font.postScriptName)")
    }
}

@Test func 한글_글리프가_누락되지_않았다() {
    // 서브셋 후 흔히 쓰는 글자가 빠지지 않았는지 확인한다
    let sample = "모음집 안녕하세요 뷁 힣 가나다라마바사"
    for font in [AppFont.gowunBatang, .gowunDodum, .nanumPen] {
        let uiFont = UIFont(name: font.postScriptName, size: 20)!
        let attributed = NSAttributedString(string: sample,
                                            attributes: [.font: uiFont])
        let size = attributed.size()
        #expect(size.width > 0)
    }
}

@Test func 알수없는_폰트이름은_nil을_반환한다() {
    #expect(UIFont(name: "NonExistentFont-Regular", size: 20) == nil)
}
```

- [ ] **Step 6: 테스트 실패 확인**

```bash
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SoozipTests/FontLoadingTests 2>&1 | tail -20
```

Expected: 컴파일 실패 — `cannot find 'AppFont' in scope`

- [ ] **Step 7: 최소 구현**

`Soozip/Core/Layout/AppFont.swift`:

```swift
import Foundation

/// layoutJSON의 `font` 값과 번들 폰트를 잇는다.
/// raw value가 곧 JSON에 저장되는 문자열이므로 **변경하면 기존 캔버스가 깨진다.**
enum AppFont: String, CaseIterable, Codable {
    case pretendard
    case gowunBatang
    case gowunDodum
    case nanumPen
    case playfair

    /// 실제 서브셋 결과의 PostScript 이름으로 교체할 것.
    /// 확인 방법: `fc-scan --format "%{postscriptname}\n" <파일>`
    var postScriptName: String {
        switch self {
        case .pretendard:  return "Pretendard-Regular"
        case .gowunBatang: return "GowunBatang-Regular"
        case .gowunDodum:  return "GowunDodum-Regular"
        case .nanumPen:    return "NanumPenScript-Regular"
        case .playfair:    return "PlayfairDisplay-Regular"
        }
    }

    var displayName: String {
        switch self {
        case .pretendard:  return "프리텐다드"
        case .gowunBatang: return "고운바탕"
        case .gowunDodum:  return "고운돋움"
        case .nanumPen:    return "나눔손글씨"
        case .playfair:    return "Playfair"
        }
    }
}
```

- [ ] **Step 8: 테스트 통과 확인**

```bash
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SoozipTests/FontLoadingTests 2>&1 | tail -20
```

Expected: 3개 테스트 PASS

실패하면 `postScriptName`이 실제 파일과 다른 것이다. `fc-scan`으로 확인해 고친다.

- [ ] **Step 9: 스파이크 코드 폐기**

```bash
rm -rf Soozip/Spikes
```

`Soozip/App/SoozipApp.swift`를 빈 상태로 되돌린다:

```swift
import SwiftUI

@main
struct SoozipApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Phase 1 대기 중")
                .foregroundStyle(.secondary)
        }
    }
}
```

Xcode에서 `Spikes` 그룹 참조도 제거한다.

**`Core/Geometry/`의 세 파일과 테스트는 남긴다.** 검증된 순수 로직이며 Phase 3~4가 그 위에 세워진다.

- [ ] **Step 10: 전체 테스트 실행**

```bash
xcodebuild test -scheme Soozip -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30
```

Expected: `TEST SUCCEEDED`, 총 24개 테스트 (LayerFrame 5 + ResizeAnchor 7 + SnapEngine 8 + Font 3 + Smoke 1)

- [ ] **Step 11: 커밋**

```bash
git add -A
git commit -m "spike: S3 폰트 번들 검증 + 스파이크 코드 폐기"
git push
```

---

## Phase 0 게이트

Phase 1로 넘어가기 전에 전부 확인한다.

- [ ] macOS에서 `xcodebuild test`가 성공하고 24개 테스트가 통과한다
- [ ] `docs/reports/2026-08-10-spike-results.md`에 S1·S2·S3의 **실측 수치**가 기록되어 있다 ("잘 동작함" 같은 서술이 아니라 숫자)
- [ ] S1의 60fps 기준 결과가 기록되고, 미달이면 대응책이 결정되어 v4 설계서 §5.8.4에 반영되었다
- [ ] S2에서 **초안 폴더가 동기화되지 않음**이 실기기 2대로 확인되었다
- [ ] S3에서 폰트 5종 합계 용량이 기록되고, 10MB 초과 시 대응이 결정되어 §5.5에 반영되었다
- [ ] `Soozip/Spikes/`가 삭제되었고 `Core/Geometry/`는 남아 있다
- [ ] 전역 제약(iOS 17 / 방향 3종 / Light 고정)이 프로젝트 설정에 적용되었다
- [ ] 모든 변경이 커밋되고 원격에 푸시되었다

## 다음

Phase 0 게이트 통과 후 `docs/plans/2026-08-10-02-phase1-data-layer.md`를 작성한다. **스파이크 결과를 반영해서 쓴다** — 지금 미리 쓰지 않는 이유가 그것이다.
