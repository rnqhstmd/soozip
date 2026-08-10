# Phase 0 스파이크 실측 결과

- 작성일: 2026-08-10
- 관련 계획: `docs/plans/2026-08-10-01-phase0-setup-spikes.md` (구간 A) · `docs/plans/2026-08-10-02-phase0-macos.md` (구간 B)
- 관련 설계: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md`

이 문서는 **실측 수치만** 기록한다. "잘 동작함" 같은 서술은 쓰지 않는다.

---

## S1 — 제스처 · 선택 UI · 스마트 가이드

S1은 두 축으로 나뉜다. **계산 축은 Windows에서 선검증했고, 렌더링 축은 실기기가 필요해 보류 중이다.**

| 축 | 상태 | 측정 위치 |
|---|---|---|
| 스냅 계산 비용 | ✅ **측정 완료** | Windows x86_64 · macOS arm64 (아래) |
| 프로토타입 빌드·렌더 | ✅ **확인** | iPhone 17 시뮬레이터 (S1-b) |
| SwiftUI 렌더링 fps | ⬜ **보류 — 실기기 필요** | 구간 B Task 6 |
| 회전 리사이즈 대각 고정 | ✅ **단위 테스트 통과** | Windows·macOS (`ResizeAnchorTests` 7개) |
| 핸들 히트 영역 44pt | ⬜ 보류 | 실기기 |
| 제스처 배타 처리 | ⬜ 보류 | 실기기 |

### S1-a. 스냅 계산 비용 (2026-08-10 측정)

**측정 환경**

| 항목 | 값 |
|---|---|
| 도구 | `Packages/SoozipGeometry` → `swift run -c release SnapBench` |
| 플랫폼 | Windows x86_64 (`x86_64-unknown-windows-msvc`) |
| Swift | 6.3.3 |
| 빌드 | **release** (debug는 수십 배 느려 판단에 쓸 수 없다) |
| 반복 | 워밍업 1,000회 후 50,000회 평균 |
| 캔버스 | 1080×1350, threshold 8 |

**결과**

| 레이어 수 | 1회 호출 | 60fps 예산(16.667ms) 점유율 |
|---|---|---|
| 10 (전부 축정렬) | 4.20 µs | 0.025% |
| 20 (전부 축정렬) | 6.97 µs | 0.042% |
| **42 (설계 상한)** | **14.64 µs** | **0.088%** |
| 42 (절반 회전) | 7.77 µs | 0.047% |
| 42 (전부 회전) | 0.16 µs | 0.001% |
| 100 (상한 2배 초과) | 27.56 µs | 0.165% |

**판정: 스냅 계산은 병목이 아니다.**

설계 상한인 43개 레이어(움직이는 1 + 상대 42) 상황에서 프레임 예산의 **0.088%**를 쓴다. 여유가 세 자릿수다.

**부수 확인 두 가지**

1. **복잡도는 O(n)이다.** 10→20→42→100으로 갈 때 4.20→6.97→14.64→27.56 µs로 선형 증가한다. 레이어가 늘어도 예측 가능하게 증가한다.
2. **회전 레이어 필터링이 실제로 비용을 줄인다.** 전부 회전 시 0.16 µs로 떨어지는데, 움직이는 레이어가 회전 상태면 즉시 반환하는 early return이 동작하기 때문이다. 절반 회전(7.77 µs)은 축정렬 42개(14.64 µs)의 약 절반으로, 후보 필터링이 선형으로 작동한다.

**이 측정의 한계 — 반드시 함께 읽을 것**

- **x86_64 데스크톱에서 잰 값이다.** iPhone의 ARM CPU는 이보다 느리다. 다만 격차는 통상 2~5배 수준이고 여기 여유는 1,000배 이상이라, **결론(계산은 병목이 아님)은 뒤집히지 않는다.**
- **계산만 잰 값이다.** SwiftUI 뷰 갱신, 가이드선 렌더, 제스처 이벤트 처리는 포함되지 않는다.

### S1-b. 프로토타입 시뮬레이터 확인 (2026-08-10)

`Soozip/Spikes/S1_GestureProbe.swift`를 iPhone 17 시뮬레이터에서 빌드·실행했다.

| 항목 | 결과 |
|---|---|
| 빌드 | 성공 (경고 0건) |
| 레이어 43개 렌더 | 정상 — 7열 격자로 배치됨 |
| 스냅 후보 계산 배선 | `snapCandidates`가 드래그 중 호출되도록 연결 확인 |

**이 확인의 한계 — fps는 여기서 재지 않았다.** 시뮬레이터는 Mac의 GPU를 쓰므로 프레임 수치가 실기기를 대변하지 못한다. 확인한 것은 "코드가 빌드되고 43개가 그려진다"까지이고, **60fps 판정은 여전히 실기기 측정을 기다린다.**

측정할 항목은 아래 4개다.

| 측정 | 방법 | 통과 기준 |
|---|---|---|
| 60fps | Instruments → Animation Hooks, 레이어 43개로 10초 연속 드래그 | 평균 60fps, 드롭 프레임 5% 미만 |
| 회전 리사이즈 | 레이어를 45° 회전 후 코너 드래그 | 대각 반대편이 눈에 띄게 움직이지 않음 |
| 핸들 히트 | 줌 200%에서 핸들 가장자리 탭 | 12pt 그래픽 밖 44pt 영역에서도 잡힘 |
| 제스처 배타 | 선택 유/무 상태에서 각각 핀치 | 레이어 / 캔버스로 정확히 갈림 |

**따라서 실기기에서 60fps가 미달하면 원인은 렌더링 쪽이다.** v4 §5.8.4가 제시했던 대응책 중 "스냅 계산 스로틀링"과 "후보를 화면 안 레이어로 축소"는 **효과가 거의 없다** — 이미 0.088%인 것을 줄여봐야 얻을 게 없다. 대응은 렌더링 축에서 찾아야 한다(가이드선 그리기 방식, 뷰 갱신 범위, `drawingGroup` 등).

---

## S2 — SwiftData + CloudKit

⬜ **보류.** macOS + Apple Developer 계정 + 실기기 2대가 필요하다.

측정할 항목:
- 실기기 2대 양방향 동기화 (30초 내 반영)
- 관계(`Collection ↔ Canvas`) 동기화
- **초안 폴더가 동기화되지 않음** ← Phase 2 설계 전체가 걸린 전제
- iCloud 로그아웃 시 로컬 모드 격하

---

## S3 — 폰트 번들

✅ **종료 (2026-08-10).** 용량 판정은 Windows에서, iOS 로드 확인은 macOS에서 끝냈다.

### S3-a. 원본 용량

| 폰트 | 원본 | 출처 |
|---|---|---|
| GowunBatang-Regular.ttf | 8.43 MB | Google Fonts |
| GowunDodum-Regular.ttf | 7.23 MB | Google Fonts |
| NanumPenScript-Regular.ttf | 3.20 MB | Google Fonts |
| Pretendard-Regular.otf | 1.57 MB | GitHub `orioncactus/pretendard` |
| PlayfairDisplay-Regular.ttf | 0.30 MB | Google Fonts (가변, wght 400~900) |
| **합계** | **20 MB** | 기준(10MB)의 **2배** |

라이선스는 5종 전부 **SIL OFL** 확인. 원문을 `Soozip/Resources/Fonts/licenses/`에 보관했다.

### S3-b. 서브셋 실측 — 한자 제거로는 안 줄어든다

한자·일본어를 빼고 한글 11,172자를 유지하는 서브셋을 먼저 시도했다.

| 폰트 | 원본 | 한자 제거 후 | 감소 |
|---|---|---|---|
| GowunBatang | 8.1 MB | 7.8 MB | **-4%** |
| GowunDodum | 6.9 MB | 6.7 MB | **-3%** |
| NanumPenScript | 3.1 MB | 2.0 MB | -35% |
| Pretendard | 1.6 MB | 1.3 MB | -19% |
| **합계 (+Playfair)** | 20 MB | **18 MB** | **-10%** |

**용량의 본체는 한자가 아니라 한글 음절 11,172자 자체였다.** 계획 단계의 가정("서브셋의 실익은 CJK 한자 제거에 있다")이 실측으로 뒤집혔다.

### S3-c. KS X 1001 2,350자

Python `euc_kr` 코덱은 CP949 확장을 포함해 11,172자를 전부 인코딩하므로 쓸 수 없었다. **KS X 1001 한글 영역(첫 바이트 0xB0~0xC8, 둘째 0xA1~0xFE)을 바이트로 역산**해 정확히 2,350자를 얻었다(목록: `tools/fonts/ksx1001.txt`).

| 폰트 | 11,172자 | 2,350자 |
|---|---|---|
| GowunBatang | 7.8 MB | **1.43 MB** |
| GowunDodum | 6.7 MB | **1.23 MB** |
| NanumPenScript | 2.0 MB | **1.19 MB** |
| Pretendard | 1.3 MB | 0.37 MB |

커버리지 21%. `가·나·다·안·녕·모·음·집·수` 등 일상 글자는 전부 포함, `뷁·힣·똠·꿹·쀓`은 누락.

### S3-d. 채택안 — 혼합 (5.2 MB)

| 폰트 | 한글 커버리지 | 용량 | PostScript 이름 |
|---|---|---|---|
| Pretendard | **11,172자 전부** | 1.29 MB | `Pretendard-Regular` |
| 고운바탕 | KS X 1001 | 1.43 MB | `GowunBatang-Regular` |
| 고운돋움 | KS X 1001 | 1.23 MB | `GowunDodum-Regular` |
| 나눔손글씨 | KS X 1001 | 1.19 MB | **`NanumPen-Regular`** |
| Playfair | — (영문) | 0.30 MB | `PlayfairDisplay-Regular` |
| **합계** | | **5.2 MB** | 기준의 **52%** |

**기본 폰트는 완전 커버, 감성 폰트만 제한**한다. Pretendard가 OTF/CFF 압축 덕에 전체 한글을 1.29MB에 담기 때문에 가능한 조합이다.

### S3-e. 함정 두 가지

1. **나눔손글씨의 PostScript 이름이 파일명과 다르다.** 파일은 `NanumPenScript-Regular.ttf`인데 PostScript 이름은 **`NanumPen-Regular`**다. `UIFont(name:)`은 PostScript 이름을 받으므로 계획서에 적혀 있던 값(`NanumPenScript-Regular`)으로는 **로드에 실패했을 것**이다. v4 §5.5와 플랜의 `AppFont`를 수정했다.
2. **Playfair Display는 가변 폰트**다(wght 400~900). iOS 13+에서 정상 동작하고 P0는 Regular만 쓰므로 문제없다.

### S3-f. Mac 확인 완료 (2026-08-10)

- [x] `Info.plist`의 `UIAppFonts` 등록 — `project.yml`에서 생성
- [x] `UIFont(name:)`로 5종 실제 로드 확인 — iPhone 17 시뮬레이터, `SoozipTests/FontLoadingTests` 6개 통과
- [x] 서브셋 후 한글 글리프 누락 없는지 렌더 확인

**PostScript 이름 함정을 테스트로 고정했다.** `UIFont(name: "NanumPen-Regular")`는 로드되고 `UIFont(name: "NanumPenScript-Regular")`(파일명)는 `nil`이라는 것을 둘 다 단언한다. 파일명으로 부르면 조용히 실패하는 종류라 회귀를 눈으로 잡을 수 없다.

**희귀 음절 폴백도 확인했다.** KS X 1001에 없는 `뷁힣똠`을 고운바탕으로 그려도 폭이 0이 아니다 — 글자가 사라지지 않고 시스템 폰트로 폴백해 폰트만 섞여 보인다(v4 §5.5가 의도한 동작).

**S3 종료.** 폰트 5종 5.2MB, 기준(10MB)의 52%.

---

## 환경 구성 실측 (2026-08-10)

Phase 0 진행 중 확인된 사항. 플랜 Task 2에 반영했다.

| 항목 | 결과 |
|---|---|
| Swift 툴체인 | winget `Swift.Toolchain` 6.3.3 설치 성공 |
| 선행 조건 | Visual Studio Build Tools 2022 + MSVC 14.44 + Windows SDK 10.0.26100이 **이미 존재**해 추가 설치 없음 |
| 부수 설치 | Python 3.10.11 (의존성) |
| `SDKROOT` | **미설정 시 매니페스트 컴파일부터 실패** (`unable to load standard library for target 'x86_64-unknown-windows-msvc'`) |
| Git Bash PATH | `$LOCALAPPDATA`가 `C:\...` 형식이라 PATH에 그대로 이어붙이면 `C:` 뒤 콜론이 구분자로 오인됨. `cygpath -u` 필요 |
| SPM 빈 타깃 | 소스 0개 타깃은 빌드 거부(`target is empty`). RED를 보려면 빈 파일을 먼저 둬야 함 |
| 컴파일러 타입 추론 | `Double(100 + i * 20)` 형태가 오버로드 탐색 폭발로 타입 체크 시간 초과. 타입 명시로 해결 |
| `NSString.utf8String` | Windows Foundation에서 빈 문자열 반환. 순수 Swift 문자열 처리로 대체 |

---

## macOS 크로스체크 (2026-08-10)

Windows에서 통과한 패키지를 macOS(Apple M2 / macOS 26.3 / Swift 6.3.3 / Xcode 26.6)에서 돌린 결과다.

| 패키지 | Windows | macOS 첫 시도 | 원인 |
|---|---|---|---|
| SoozipGeometry | 26 통과 | **빌드 실패** | `platforms:` 미선언 → 기본 타깃 macOS 10.13. SnapBench의 `Duration.components`가 macOS 13+ |
| SoozipLayout | 40 통과 | 40 통과 | — |
| SoozipDraft | 24 통과 | **빌드 실패** | `DraftStore: Sendable`이 `FileManager`를 보유. corelibs-foundation에서는 Sendable이지만 **Darwin에서는 아니다** |

**게이트가 예고한 "플랫폼 의존 누수"가 실제로 두 건 나왔다.** 교훈은 하나다 — **순수 Swift + Foundation만 쓴다고 플랫폼 독립이 보장되지 않는다.** 같은 `Foundation`이라도 Darwin과 corelibs는 `Sendable` 적합성이 다르고, `platforms:` 미선언은 Apple 쪽에서만 함정이 된다.

수정 후 **90개(26+40+24) 전부 통과**, 경고 0건. 수정 내역은 `b88e611`·`7230b5d`.

부수 확인 하나. `platforms:`는 **의존 사슬 전체가 같은 값을 들어야 한다.** SoozipGeometry에만 선언했더니 SoozipLayout이 "macos 10.13을 요구하는데 macos 13.0을 요구하는 제품에 의존한다"며 거부했다. 세 패키지 모두 `[.iOS(.v17), .macOS(.v13)]`으로 맞췄다.

### SnapBench 재측정 — Apple Silicon (M2)

| 레이어 수 | Windows x86_64 | macOS arm64 | 프레임 예산 점유율(arm64) |
|---|---|---|---|
| 10 (전부 축정렬) | 4.20 µs | 1.10 µs | 0.007% |
| 20 (전부 축정렬) | 6.97 µs | 1.39 µs | 0.008% |
| **42 (설계 상한)** | 14.64 µs | **2.29 µs** | **0.014%** |
| 42 (절반 회전) | 7.77 µs | 1.63 µs | 0.010% |
| 42 (전부 회전) | 0.16 µs | 0.07 µs | 0.000% |
| 100 (상한 2배) | 27.56 µs | 5.62 µs | 0.034% |

**arm64가 6.4배 빠르다.** S1-a에 적어둔 한계 문구("iPhone의 ARM CPU는 이보다 느리다")는 x86_64 데스크톱과 비교한 보수적 가정이었는데 M 계열에서는 반대로 나왔다. iPhone의 A 계열은 M 계열보다 느리므로 이 수치가 곧 iPhone 값은 아니지만, **"계산은 병목이 아니다"라는 결론의 여유는 오히려 더 커졌다.**

10개(1.10 µs)와 20개(1.39 µs)의 차이는 측정 노이즈 수준이다. 반복 실행 시 ±0.5 µs 흔들린다. 42개 값만 2.2~2.3 µs로 안정적이며, 어느 쪽이든 프레임 예산의 0.01% 언저리라 구분에 의미가 없다.

---

## 게이트 진행 상황

**구간 A (Windows)**
- [x] `SoozipGeometry` 26개 통과 (Vec2 4 + LayerFrame 6 + ResizeAnchor 7 + SnapEngine 9)
- [x] `SoozipLayout` 40개 통과 (AppFont 7 + Layer 14 + JSON 계약 5 + Document 14)
- [x] 두 패키지 모두 CoreGraphics·SwiftUI import 0건 (`Foundation`만)
- [x] **스냅 계산 성능 실측** — 프레임 예산의 0.088%
- [x] **폰트 5종 확정** — 혼합 서브셋 5.2MB (기준의 52%)

**Phase 0 범위 밖이나 Windows에서 선행한 것 — 전부 Phase 2 산출물**
- [x] **layoutJSON v1 Codec** (`Packages/SoozipLayout`, 40 tests) — 레이어 5종 라운드트립, JSON 계약(v4 §8 형식 일치), 상위 버전 거부, 캔버스 밖 좌표 보존, 레이어 상한 검증
- [x] **초안 파일 저장소** (`Packages/SoozipDraft`, 24 tests) — `meta.json`/`layout.json`/`photos/` I/O, 모음집당 1개 조회, 고아 정리 3조건(무소속·7일 초과·메타 손상)

두 패키지 모두 **루트 경로를 주입받거나 Foundation만 쓰는 설계**라 Mac 없이 완주했다. Phase 2에 남은 것은 **승격 트랜잭션 7단계**뿐이며, SwiftData 쓰기 단계가 있어 Mac이 필요하다.

`DraftStore`를 만들면서 **v4에 `meta.json`을 추가**했다. 고아 정리는 "소속 모음집이 없거나 7일 이상 방치된 폴더"를 지우는데, 폴더명(UUID)만으로는 소속을 알 수 없고 파일 mtime은 백업·복원으로 바뀌어 방치 기간의 근거가 못 된다.

**구간 B (macOS)**
- [x] macOS에서 같은 26개 통과 — 플랫폼 의존 누수 2건 수정 후. `SoozipLayout` 40 · `SoozipDraft` 24를 더해 **90개**
- [x] `xcodebuild test` 앱 테스트 **9개 통과** (CGInterop 3 + 폰트 6) — *로드맵의 "6개"는 `AppFont`가 앱 타깃에 있을 때의 계산이었다*
- [ ] S1 실기기 4개 기준 실측
- [ ] S2 초안 미동기화 확인
- [x] S3 폰트 용량 확인 — 5.2MB, 로드·글리프 확인 완료
