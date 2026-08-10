# collection 아키텍처

> 전체 구조 요약과 주제별 상세 문서 링크를 관리합니다.

## 시스템 구조

```
CollectionHomeView (탭1, 앱 첫 화면)
 ├─ CollectionCarousel        가로 스크롤 · 맨 좌측 [+] 고정
 │   └─ CollectionCard        표지(대표 캔버스 썸네일) + 이름 + 캔버스 수
 ├─ CollectionGridView        「전체 보기」
 ├─ CollectionEditSheet       생성 · 이름 변경
 └─ SearchView                모음집 이름 + 캔버스 제목 통합 검색

CollectionDetailView
 ├─ CanvasGrid                최신순 / 오래된순
 ├─ DraftBanner               "이어서 만들까요?"
 └─ [+] → canvas 도메인으로 위임
```

## 데이터 모델

```swift
@Model final class Collection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var coverCanvasID: String = ""      // 비면 가장 최근 캔버스
    var canvases: [Canvas]? = []
}
```

**`coverCanvasID`를 관계가 아니라 문자열로 둔 이유**: `Collection → Canvas` 관계가 이미 있는데 대표 캔버스로 관계를 하나 더 걸면 CloudKit에서 순환 참조 구성이 까다로워진다. UUID 문자열이면 대상이 사라져도 빈 값 취급으로 안전하게 폴백된다.

## 표지 계산 규칙

```
coverCanvasID 가 비어 있지 않고 && 그 캔버스가 존재하면
    → 그 캔버스의 renderedPNG
아니면 가장 최근 캔버스가 있으면
    → 그 캔버스의 renderedPNG
아니면
    → 연한 단색 카드 + 이름
```

**재계산이 필요한 시점** — 이 셋을 빠뜨리면 표지가 사라진 캔버스나 남의 모음집 캔버스를 가리킨다.
1. 캔버스 저장(승격) 시 — 모음집이 비어 있었다면 이 캔버스를 대표로
2. 캔버스 삭제 시 — 대표였다면 비우고 최근 캔버스로 승계
3. **캔버스를 다른 모음집으로 이동 시 — 양쪽 모두 재계산**

## 정렬

- 기본은 `createdAt` 오름차순 = 생성 순서
- 사용자가 드래그로 재배치하면 `sortIndex`를 다시 매긴다
- **두 기기에서 동시에 재배치해 `sortIndex`가 중복되면 `createdAt` 오름차순으로 타이브레이크**

## 주제 문서

| 주제 | 설명 |
|------|------|
| (없음) | 필요 시 추가 |

## 참조

- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §2, §4
