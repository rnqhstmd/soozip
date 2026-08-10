# soozip

흰 캔버스에 사진·텍스트·도형을 자유롭게 배치해 한 장을 만들고, 그 장들을 직접 만든 모음집에 담는 iOS 앱.
**서버도 계정도 없습니다.** 데이터는 기기와 사용자의 iCloud에만 있습니다.

이름은 "수집"에서 왔습니다.

## 현재 상태

**Phase 0 진행 중.** 기하·레이아웃·초안 저장소 3개 패키지가 완성됐고 Windows·macOS 양쪽에서 테스트 90개가 통과합니다. Xcode 앱 골격과 실기기 스파이크가 남았습니다.

| 패키지 | 내용 | 테스트 |
|---|---|---|
| `SoozipGeometry` | 좌표 변환 · 리사이즈 · 스냅 후보 계산 | 26 |
| `SoozipLayout` | layoutJSON v1 Codec · 폰트 5종 · 레이어 상한 | 40 |
| `SoozipDraft` | 초안 파일 I/O · 고아 정리 | 24 |

세 패키지 모두 CoreGraphics·SwiftUI에 의존하지 않아 Windows에서 `swift test`가 그대로 돕니다.

## 문서

| 문서 | 내용 |
|---|---|
| [설계 SSOT](docs/specs/2026-08-10-moumzip-mvp-design-v4.md) | 정보 구조 · 에디터 · 워크플로우 · 데이터 모델 · 우선순위 (v4) |
| [구현 로드맵](docs/plans/2026-08-10-00-roadmap.md) | Phase 0~9와 각 단계의 통과 게이트 |
| [Phase 0 계획](docs/plans/2026-08-10-01-phase0-setup-spikes.md) | 태스크 단위 실행 계획 |
| [도메인 컨텍스트](context/) | collection · canvas · editor · media · sync · profile — "왜 그렇게 정했는가" |

설계가 바뀌면 SSOT와 `context/`를 함께 고칩니다. 코드가 문서를 앞서가지 않습니다.

## 기술 스택

| 항목 | 선택 |
|---|---|
| 플랫폼 | iOS 17+ (Xcode 26 / iOS 26 SDK) |
| UI | SwiftUI |
| 영속성 | SwiftData + CloudKit |
| 초안 | 로컬 파일 (CloudKit 동기화 대상 아님) |
| 테스트 | Swift Testing |
| 외부 의존성 | 없음 |

## 개발 환경

**macOS + Xcode 26이 필요합니다.**

```bash
git clone https://github.com/rnqhstmd/soozip.git ~/dev/soozip
cd ~/dev/soozip
```

이후 절차는 [Phase 0 계획](docs/plans/2026-08-10-01-phase0-setup-spikes.md)을 따릅니다.
