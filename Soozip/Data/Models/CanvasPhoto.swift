import Foundation
import SwiftData

@Model final class CanvasPhoto {
    var id: UUID = UUID()

    // 레이어의 assetId가 이 id를 가리켜 복제 레이어들이 같은 레코드를 공유한다.
    // 레이어 하나 지웠다고 여기를 지우면 나머지가 깨진다.
    @Attribute(.externalStorage) var data: Data = Data()

    var canvas: Canvas?

    // iOS 26 SDK의 @Model은 전 속성에 기본값이 있어도 이니셜라이저를 요구한다
    // (`error: @Model requires an initializer be provided`).
    init() {}
}
