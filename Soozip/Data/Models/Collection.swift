import Foundation
import SwiftData

@Model final class Collection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0

    /// 관계가 아니라 String인 이유 (v4 §7.1): 대표 캔버스로 관계를 하나 더 걸면
    /// CloudKit 순환 참조 구성이 까다로워진다.
    /// 여기에 직접 대입하지 마라 — 유일한 대입 지점은 `CoverPolicy`다
    /// (`reconcile` 자동 재계산 · `designate` 사용자 지정).
    var coverCanvasID: String = ""

    // 역관계는 Canvas.collection 쪽에만 선언한다. 양쪽에 걸면 SwiftData가
    // 관계를 두 개로 보고 스키마 구성에서 죽는다.
    @Relationship(deleteRule: .cascade, inverse: \Canvas.collection)
    var canvases: [Canvas]? = []

    // iOS 26 SDK의 @Model은 전 속성에 기본값이 있어도 이니셜라이저를 요구한다
    // (`error: @Model requires an initializer be provided`).
    init() {}
}
