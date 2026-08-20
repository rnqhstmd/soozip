## 코드 맵: EDITOR-9 — 캔버스 경계와 레이어 이탈

### 핵심 파일

- `Packages/SoozipGeometry/Sources/SoozipGeometry/CanvasSurface.swift:70-88` → **`workArea`(캔버스 2배 사각형) + `clampedToWorkArea(_:)`가 이미 있다.** doc이 명시적으로 *"`EDITOR-9`(레이어 경계)가 이 사각형을 다시 정의하지 않도록 공개한다"*고 적혀 있다. EDITOR-9는 이것을 **재정의하지 않고 그대로 호출**해야 한다.
- `Packages/SoozipGeometry/Sources/SoozipGeometry/LayerFrame.swift:52-98` → 레이어 기하(`center`·`size`·`rotation` 라디안). `corner(_:)`가 **회전 반영된 월드 좌표 코너 4점**을 낸다 — 클리핑·고스트 판정의 입력.
- `Packages/SoozipGeometry/Sources/SoozipGeometry/Vec2.swift:7-33` → `Vec2`·`Size2`. Foundation만 의존(Windows 빌드 유지).
- `Packages/SoozipGeometry/Sources/SoozipGeometry/SnapEngine.swift:29-45` → `private struct AABB`가 **회전 0 전용 축 정렬 박스**를 이미 만든다. 회전 레이어를 다루는 EDITOR-9는 이 구조를 쓸 수 없다(회전체의 AABB는 실제 형태와 어긋난다는 것이 SnapEngine이 회전 레이어를 배제하는 이유다).

### 참조 파일

- `Packages/SoozipGeometry/Tests/SoozipGeometryTests/CanvasSurfaceTests.swift:180-218,287` → `작업_영역_밖으로는_네_방향_모두_팬되지_않는다` · `연속으로_팬해도_작업_영역을_벗어나지_못한다` · `경계까지_팬한_상태로_회전해도_여전히_경계다`. **`workArea`는 `centered(on:)` 경로로만 증인이 있고 `clampedToWorkArea`를 직접 호출하는 테스트는 0건**이다 — EDITOR-9가 이 함수를 재사용하면 그 자체가 두 번째 증인 축이 된다.
- `Packages/SoozipGeometry/Sources/SoozipGeometry/RotationSnap.swift` → 직전 단위(EDITOR-8). **단위 규약의 선례**: 모델은 라디안, 판정 본체는 도. 인자 라벨이 유일한 방어.
- `Packages/SoozipGeometry/Sources/SoozipGeometry/HandlePlacement.swift` → 화면 좌표 산출의 선례. EDITOR-9는 **논리좌표 단위**라 이 축과 다르다.
- `Packages/SoozipGeometry/Sources/SoozipGeometry/ResizeAnchor.swift` → `LayerFrame.resizeLimits`·`clamped`(EDITOR-7). **이름 충돌 주의** — `clamped`(크기 클램프)와 EDITOR-9의 중심 클램프는 다른 축이다.
- `docs/specs/2026-08-10-moumzip-mvp-design-v4.md:364-376` → §5.10 SSOT.
- `context/editor/architecture.md:69-77` → 캔버스 경계 요약표.

### 설정

- `Packages/SoozipGeometry/Package.swift` → 의존성 **Foundation만**. CoreGraphics·SwiftUI·UIKit 금지.
- `.claude/config.json` → `swift-ios` (test=`./scripts/test.sh`, warningPattern=`warning:`).

### v4 §5.10 원문 요약 (SSOT)

| 구분 | 동작 |
|---|---|
| 에디터 표시 | 캔버스 영역은 정상 렌더. 밖으로 나간 부분은 **30% 불투명도 고스트** |
| 경계 처리 | 캔버스 사각형으로 클리핑. **잘린 데이터는 버리지 않는다** — `x,y`만 밖에 있을 뿐 레이어는 온전 |
| 익스포트·썸네일 | 캔버스 영역만. 고스트 미렌더 |
| 회수 | 줌 아웃(50%) 또는 캔버스 팬 |
| 완전 이탈 방지 | **레이어 중심**이 작업 영역(캔버스 2배) 밖으로 못 나감 |

> **클램프하지 않고 클리핑을 택한 이유**(v4 원문): 가장자리에서 잘린 사진·화면 밖으로 흘러나가는 도형은 콜라주의 기본 문법이다. 중심을 캔버스 안에 가두면 이 표현이 통째로 불가능해진다. **"영영 못 잡는 레이어"만** 작업 영역 경계로 막는다.

### ⚠️ 로드맵 표현의 모호성 (requirements에서 해소 필요)

로드맵 122줄은 `"고스트 판정(30%)"`이라고 적혀 있다. **v4 원문에서 30%는 불투명도이지 판정 임계가 아니다** — "30% 이상 벗어나면 고스트"가 아니라 "벗어난 부분을 30% 불투명도로 그린다"이다. 이 30%는 **렌더 상수(`EDITOR-11`)이지 EDITOR-9의 로직이 아닐 가능성이 높다.** PRD에서 확정해야 한다.
