import SwiftData

/// 앱 배선(`SoozipApp`)·테스트 컨테이너·스키마 검사 테스트가 **같은 목록**을 본다.
/// 세 곳이 각자 배열을 들면 한 곳만 빠졌을 때 관계가 통째로 깨지는데
/// 증상이 컴파일이 아니라 런타임에야 나온다.
enum SoozipSchema {
    static let models: [any PersistentModel.Type] = [Collection.self, Canvas.self, CanvasPhoto.self]
}
