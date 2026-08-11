import Testing
import Foundation
import SwiftData
@testable import Soozip

// SoozipSchema.models로 만든 Schema를 리플렉션해서 모델 3종의 선언을 검증한다.
// ModelContainer 없이도 Schema(SoozipSchema.models).entities 로 attributes/relationships를
// 들여다볼 수 있다(iOS 26 SDK에서 실측 확인됨).

private func entity(named name: String, in schema: Schema) -> Schema.Entity? {
    schema.entities.first { $0.name == name }
}

private func soozipSchema() -> Schema {
    Schema(SoozipSchema.models)
}

private func makeInMemoryContext() throws -> ModelContext {
    let container = try ModelContainer(
        for: soozipSchema(),
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    return ModelContext(container)
}

// MARK: - AC-1: 모든 속성은 기본값을 갖거나 optional이다

@Test func Collection의_모든_속성은_기본값을_갖거나_optional이다() throws {
    let schema = soozipSchema()
    let collectionEntity = try #require(entity(named: "Collection", in: schema))
    for attr in collectionEntity.attributes {
        #expect(attr.defaultValue != nil || attr.isOptional, "\(attr.name)은 기본값도 optional도 아니다")
    }
}

@Test func Canvas의_모든_속성은_기본값을_갖거나_optional이다() throws {
    let schema = soozipSchema()
    let canvasEntity = try #require(entity(named: "Canvas", in: schema))
    for attr in canvasEntity.attributes {
        #expect(attr.defaultValue != nil || attr.isOptional, "\(attr.name)은 기본값도 optional도 아니다")
    }
}

@Test func CanvasPhoto의_모든_속성은_기본값을_갖거나_optional이다() throws {
    let schema = soozipSchema()
    let canvasPhotoEntity = try #require(entity(named: "CanvasPhoto", in: schema))
    for attr in canvasPhotoEntity.attributes {
        #expect(attr.defaultValue != nil || attr.isOptional, "\(attr.name)은 기본값도 optional도 아니다")
    }
}

// MARK: - AC-2: 어떤 속성/관계에도 unique 제약이 없다

@Test func 모든_모델의_속성과_관계에는_unique_제약이_없다() {
    // 속성만 보면 반쪽이다 — @Relationship에도 unique를 걸 수 있으므로
    // relationships까지 함께 순회한다.
    let schema = soozipSchema()
    for model in schema.entities {
        for attr in model.attributes {
            #expect(!attr.isUnique, "\(model.name).\(attr.name)에 unique 제약이 있다")
        }
        for rel in model.relationships {
            #expect(!rel.isUnique, "\(model.name).\(rel.name) 관계에 unique 제약이 있다")
        }
    }
}

// MARK: - AC-3: Canvas.collection <-> Collection.canvases, Canvas.photos <-> CanvasPhoto.canvas는 양방향 optional

@Test func Canvas_collection과_Collection_canvases_관계는_양쪽_모두_optional이다() throws {
    let schema = soozipSchema()
    let collectionEntity = try #require(entity(named: "Collection", in: schema))
    let canvasEntity = try #require(entity(named: "Canvas", in: schema))
    let canvases = try #require(collectionEntity.relationships.first { $0.name == "canvases" })
    let collection = try #require(canvasEntity.relationships.first { $0.name == "collection" })
    #expect(canvases.isOptional)
    #expect(collection.isOptional)
}

@Test func CanvasPhoto_canvas와_Canvas_photos_관계는_양쪽_모두_optional이다() throws {
    let schema = soozipSchema()
    let canvasEntity = try #require(entity(named: "Canvas", in: schema))
    let canvasPhotoEntity = try #require(entity(named: "CanvasPhoto", in: schema))
    let photos = try #require(canvasEntity.relationships.first { $0.name == "photos" })
    let canvas = try #require(canvasPhotoEntity.relationships.first { $0.name == "canvas" })
    #expect(photos.isOptional)
    #expect(canvas.isOptional)
}

// MARK: - deleteRule 계약 (AC-16/17 cascade 삭제의 실제 메커니즘 — 선언이 바뀌면 여기서 먼저 빨개진다)

@Test func Collection_canvases는_cascade_삭제이며_inverse는_collection이다() throws {
    let schema = soozipSchema()
    let collectionEntity = try #require(entity(named: "Collection", in: schema))
    let canvases = try #require(collectionEntity.relationships.first { $0.name == "canvases" })
    #expect(canvases.deleteRule == .cascade)
    #expect(canvases.inverseName == "collection")
}

@Test func Canvas_photos는_cascade_삭제이며_inverse는_canvas이다() throws {
    let schema = soozipSchema()
    let canvasEntity = try #require(entity(named: "Canvas", in: schema))
    let photos = try #require(canvasEntity.relationships.first { $0.name == "photos" })
    #expect(photos.deleteRule == .cascade)
    #expect(photos.inverseName == "canvas")
}

// MARK: - AC-4: sortIndex/coverCanvasID 타입, 관계가 아닌 배열 속성 부재

@Test func sortIndex는_Int_타입으로_선언된다() throws {
    let schema = soozipSchema()
    let collectionEntity = try #require(entity(named: "Collection", in: schema))
    let sortIndex = try #require(collectionEntity.attributes.first { $0.name == "sortIndex" })
    #expect(ObjectIdentifier(sortIndex.valueType) == ObjectIdentifier(Int.self))
}

@Test func coverCanvasID는_String_타입으로_선언된다() throws {
    let schema = soozipSchema()
    let collectionEntity = try #require(entity(named: "Collection", in: schema))
    let coverCanvasID = try #require(collectionEntity.attributes.first { $0.name == "coverCanvasID" })
    #expect(ObjectIdentifier(coverCanvasID.valueType) == ObjectIdentifier(String.self))
}

@Test func 관계가_아닌_배열_타입_속성은_존재하지_않는다() {
    // 화이트리스트 밖 타입(예: [String], [Int])이 attributes에 섞여 있으면
    // 그건 배열을 관계가 아니라 값 속성으로 잘못 선언했다는 뜻이다.
    let allowedTypes: Set<ObjectIdentifier> = [
        ObjectIdentifier(UUID.self),
        ObjectIdentifier(String.self),
        ObjectIdentifier(Date.self),
        ObjectIdentifier(Int.self),
        ObjectIdentifier(Data.self),
        ObjectIdentifier(Optional<Data>.self)
    ]
    let schema = soozipSchema()
    for model in schema.entities {
        for attr in model.attributes {
            #expect(
                allowedTypes.contains(ObjectIdentifier(attr.valueType)),
                "\(model.name).\(attr.name)은 허용되지 않은 타입이다: \(attr.valueType)"
            )
        }
    }
}

// MARK: - AC-5: 인자 없는 init()으로 생성한 모델이 ModelContainer에 저장된다

@Test func Collection은_인자_없이_생성되어_컨테이너에_저장된다() throws {
    let context = try makeInMemoryContext()
    context.insert(Collection())
    try context.save()
}

@Test func Canvas는_인자_없이_생성되어_컨테이너에_저장된다() throws {
    let context = try makeInMemoryContext()
    context.insert(Canvas())
    try context.save()
}

@Test func CanvasPhoto는_인자_없이_생성되어_컨테이너에_저장된다() throws {
    let context = try makeInMemoryContext()
    context.insert(CanvasPhoto())
    try context.save()
}

// MARK: - 스키마 SSOT는 정식 모델만 담는다 (앱 배선 회귀 방지)

@Test func 스키마는_정식_모델_3종만_담는다() {
    // Phase 0의 프로브 모델(`ProbeCollection`·`ProbeCanvas`)이 앱 컨테이너에 남으면
    // 정식 모델이 통째로 빠진 채 앱이 뜬다. **증상이 컴파일이 아니라 런타임에야
    // 나오는** 종류라 선언 자체를 테스트로 못박는다.
    let names = Set(Schema(SoozipSchema.models).entities.map(\.name))
    #expect(names == ["Collection", "Canvas", "CanvasPhoto"])
}
