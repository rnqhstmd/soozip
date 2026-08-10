# Phase 0 스파이크 실측 결과

- 작성일: 2026-08-10
- 관련 계획: `docs/plans/2026-08-10-01-phase0-setup-spikes.md`
- 관련 설계: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md`

이 문서는 **실측 수치만** 기록한다. "잘 동작함" 같은 서술은 쓰지 않는다.

---

## S1 — 제스처 · 선택 UI · 스마트 가이드

S1은 두 축으로 나뉜다. **계산 축은 Windows에서 선검증했고, 렌더링 축은 실기기가 필요해 보류 중이다.**

| 축 | 상태 | 측정 위치 |
|---|---|---|
| 스냅 계산 비용 | ✅ **측정 완료** | Windows x86_64 (아래) |
| SwiftUI 렌더링 · 제스처 응답 | ⬜ 보류 | 실기기 (Task 7) |
| 회전 리사이즈 대각 고정 | ✅ **단위 테스트 통과** | Windows (Task 4) |
| 핸들 히트 영역 44pt | ⬜ 보류 | 실기기 (Task 7) |
| 제스처 배타 처리 | ⬜ 보류 | 실기기 (Task 7) |

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

**따라서 Task 7에서 60fps가 미달하면 원인은 렌더링 쪽이다.** v4 §5.8.4가 제시했던 대응책 중 "스냅 계산 스로틀링"과 "후보를 화면 안 레이어로 축소"는 **효과가 거의 없다** — 이미 0.088%인 것을 줄여봐야 얻을 게 없다. 대응은 렌더링 축에서 찾아야 한다(가이드선 그리기 방식, 뷰 갱신 범위, `drawingGroup` 등).

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

✅ **용량 판정 완료 (2026-08-10, Windows).** iOS 로드 확인만 Mac에 남았다.

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

### S3-f. Mac에 남은 것

- [ ] `Info.plist`의 `UIAppFonts` 등록
- [ ] `UIFont(name:)`로 5종 실제 로드 확인
- [ ] 서브셋 후 한글 글리프 누락 없는지 렌더 확인

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
- [ ] macOS에서 같은 26개 통과
- [ ] `xcodebuild test` 앱 테스트 6개 통과
- [ ] S1 실기기 4개 기준 실측
- [ ] S2 초안 미동기화 확인
- [ ] S3 폰트 용량 확인
