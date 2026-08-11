# SwiftData 실측 — 문서로 알 수 없어 직접 재현한 동작

- 작성일: 2026-08-11
- 수정일: 2026-08-11
- 관련 레포: rnqhstmd/soozip

> Phase 1(데이터 레이어) 구현 중 **실행해서 확인한 것만** 적는다.
> 여기 있는 항목은 전부 설계 초안의 가정을 뒤집었거나 테스트를 빨갛게 만든 것이다.
> 추측은 넣지 않는다 — **틀린 "왜"는 없는 것보다 나쁘다.**
>
> 측정 환경: iOS 26 SDK / iPhone 17 Pro 시뮬레이터 / 인메모리 `ModelContainer`

## 1. 관계 배열은 `save()` 전까지 삭제·이동을 반영하지 않는다. fetch는 즉시 반영한다

가장 중요한 항목이다. **이 비대칭이 유령 표지의 원천이다.**

```swift
context.delete(canvas)
collection.canvases          // 아직 삭제된 캔버스가 들어 있다
try context.fetch(...)       // 이미 빠져 있다
```

표지 재계산은 "이 모음집에 남은 캔버스"를 세어야 하는데, 관계 배열을 쓰면 방금 지운 캔버스를 후보로 세어 **사라진 캔버스를 표지로 남긴다.**

**그래서 `LibraryRepository`의 쓰기 경로가 이 순서로 고정돼 있다:**

```
변경 → save() → 표지 재계산 → save()
```

`save()`를 두 번 부르는 것이 낭비로 보여 합치고 싶어지지만, **합치는 순간 재계산이 옛 데이터를 본다.** 이 순서를 한 곳(`applyThenReconcileCover`)에만 두어 호출부가 틀릴 수 없게 했다.

후보 목록의 유일한 출처도 fetch다(`canvasesFetched`). 모음집이 늘수록 느린 쪽이지만, 조회 결과를 저장 시점에 의존시키지 않으려고 그쪽을 택했다.

## 2. `isDeleted`는 `save()` 이후 `false`로 되돌아온다

```swift
context.delete(canvas)
canvas.isDeleted        // true
try context.save()
canvas.isDeleted        // false ← 지워졌는데 false다
```

**삭제 검증에 `isDeleted`를 쓰면 안 된다.** 테스트는 전부 `context.fetchCount(FetchDescriptor<T>())`로 확인한다.

관련해서, 삭제 후에도 `canvas.collection`은 non-nil로 살아 있다. 그래도 `deleteCanvas`는 소속을 **지우기 전에** 잡아 둔다 — 삭제된 객체의 속성 접근에 의존하지 않기 위해서다.

## 3. `ModelContext`의 `autosaveEnabled` 기본값은 `true`다

테스트에서 끄지 않으면 autosave가 "save → 재계산" 순서 버그를 가려 버린다. **순서를 틀리게 짜도 테스트가 초록이 되는 것이 가장 나쁜 상태**라, 테스트 하네스(`withLibrary`)가 명시적으로 끈다.

```swift
context.autosaveEnabled = false
```

## 4. `deleteRule: .cascade`는 단독으로 전이까지 발화한다

초안 설계는 수동 `purge(_:)`를 두려 했다. 근거는 "SwiftData의 cascade 발화 시점이 흔들린 전례가 있어 프레임워크에 맡길 수 없다"였는데, **실측으로 반증됐다.**

```
모음집 삭제 → (collection, canvas, photo) = (0, 0, 0)
```

두 검증자가 독립적으로 확인했고 전이 cascade까지 정상 발화한다. 근거가 사라진 중복 경로는 남기지 않았다 — **남기면 오히려 새 버그를 만든다:**

> `purge`를 유지한 채 누군가 `deleteRule`을 `.nullify`로 바꾸면 리포지토리 경로는 여전히 정상 동작하므로 테스트가 전부 초록이다. 조용히 깨지는 것은 Phase 6의 `@Query` + 스와이프 삭제 경로 하나뿐이다.

대신 선언을 **유일한 계약**으로 두고 두 층으로 고정했다.

1. `ModelSchemaTests`가 `deleteRule == .cascade`와 `inverseName`을 단언한다
2. **리포지토리를 우회하는 삭제 테스트 1건** — `context.delete(collection)` 직접 호출 후 `fetchCount`로 자식 소멸 확인. 이 경로가 곧 Phase 6의 실제 호출부다

## 5. `DateInterval.contains(_:)`는 닫힌 구간이다

`end`를 **포함한다.** "이번 달" 계산에서 다음 달 1일 00:00에 기록된 캔버스가 이번 달로 새어 들어왔다.

```swift
// 틀림 — 9/1 00:00이 8월로 잡힌다
month.contains(canvas.createdAt)

// 맞음
month.start <= canvas.createdAt && canvas.createdAt < month.end
```

경계 테스트(7/31 23:59 · 8/1 00:00 · 8/31 23:59 · 9/1 00:00)가 빨개져서 발견했다. **경계를 분 단위로 찍는 테스트가 아니었으면 못 잡았다.**

## 6. `@Model`은 전 속성에 기본값이 있어도 이니셜라이저를 요구한다

iOS 26 SDK에서 `error: @Model requires an initializer be provided`가 난다. 매크로가 만들어 주지 않는다.

```swift
@Model final class Collection {
    var id: UUID = UUID()
    // ... 전 속성 기본값 있음
    init() {}          // ← 그래도 필요하다
}
```

## 7. 역관계는 한쪽에만 선언한다

양쪽에 `@Relationship(inverse:)`를 걸면 SwiftData가 관계를 두 개로 보고 **스키마 구성에서 죽는다.**

```swift
@Model final class Collection {
    @Relationship(deleteRule: .cascade, inverse: \Canvas.collection)
    var canvases: [Canvas]? = []      // ← 여기에만
}

@Model final class Canvas {
    var collection: Collection?        // ← 여기는 평범한 옵셔널
}
```

## 8. 앱·테스트 타깃에서 stdlib `Collection` 제네릭 제약을 쓰지 말 것

우리 모델 타입 이름이 `Collection`이라 stdlib과 충돌한다. **실측: 테스트 모듈에서 `Soozip.Collection`이 모호성 에러 없이 조용히 이긴다.** 제네릭 제약 자리(`<C: Collection>`)에서만 컴파일이 깨진다. 써야 하면 `Swift.Collection`으로 한정한다.

타입 이름을 안 바꾼 이유는 **타입명이 곧 CloudKit 레코드 타입명**이라 첫 심사 후 개명이 불가능해서다. 문서·코드 일치를 우선했다.

## 9. `.externalStorage`는 300KB 블롭도 정상 왕복한다

초안 설계의 "인메모리 테스트에서는 블롭을 작게 유지하라"는 주의는 근거가 없어 삭제했다.

## 10. `[any PersistentModel.Type]`은 `-swift-version 6`에서 진단 0건이다

초안은 "Sendable 적합성 때문에 `static let`이 Swift 6에서 진단에 걸린다"고 적었으나 **실측 결과 진단이 없다.** `SoozipSchema.models`는 `static let`이다.

## 부수 발견 — Swift Testing

`#expect(try ...)`만 있고 **문 수준 `try`가 없는 클로저는 비throwing으로 추론된다.** 매크로 확장이 클로저 타입 추론보다 나중이라 매크로 안의 `try`가 추론에 안 잡히고, 확장된 코드가 `errors thrown from here are not handled`로 깨진다.

```swift
// 깨짐
try withStats { _, stats in
    #expect(try stats.collectionCount() == 0)
}

// 됨 — try를 문 수준으로 올린다
try withStats { _, stats in
    let count = try stats.collectionCount()
    #expect(count == 0)
}
```

## 아직 측정하지 못한 것

| 항목 | 필요 조건 |
|---|---|
| CloudKit 실기기 2대 동기화 | Apple Developer 계정 + 같은 iCloud 계정 기기 2대 |
| **초안(`Drafts/`)이 동기화되지 않는지** | 〃 — **Phase 2 승격 트랜잭션 설계 전체의 전제** |
| LWW 충돌 실동작 | 〃 |

## 참조

- Phase 1 설계·결정 이력: `.dev/feat-data-layer/design.md`, `state.md` (작업 브랜치 산출물이라 병합 후 사라질 수 있음)
- 스파이크 결과: `docs/reports/2026-08-10-spike-results.md` (S2-a 모델 제약 검증)
- 설계 SSOT: `docs/specs/2026-08-10-moumzip-mvp-design-v4.md` §7
