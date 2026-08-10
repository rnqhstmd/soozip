import Foundation
import SwiftData
import SoozipLayout

@Model final class Canvas {
    var id: UUID = UUID()
    var aspect: Int = 0
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var layoutJSON: Data = Data()

    // 역관계는 CanvasPhoto.canvas 쪽에만 선언한다. 양쪽에 걸면 SwiftData가
    // 관계를 두 개로 보고 스키마 구성에서 죽는다.
    @Relationship(deleteRule: .cascade, inverse: \CanvasPhoto.canvas)
    var photos: [CanvasPhoto]? = []

    @Attribute(.externalStorage) var renderedPNG: Data?
    var collection: Collection?

    // iOS 26 SDK의 @Model은 전 속성에 기본값이 있어도 이니셜라이저를 요구한다
    // (`error: @Model requires an initializer be provided`).
    init() {}
}

extension Canvas {
    /// 저장은 Int, 사용은 enum. **extension에 두는 이유**: 클래스 본문의 계산
    /// 프로퍼티는 SwiftData가 스키마 후보로 훑는다. 첫 심사 후 스키마 동결이
    /// 걸리므로 저장 대상이 아닌 것은 확실히 밖에 둔다.
    var aspectPreset: CanvasAspect {
        get { CanvasAspect(rawValue: aspect) ?? .post }
        set { aspect = newValue.rawValue }
    }
}
