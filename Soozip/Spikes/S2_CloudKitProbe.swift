import SwiftUI
import SwiftData
import SoozipDraft

// S2 스파이크 전용. Phase 1에서 Data/Models/ 아래 정식 모델로 대체하고 삭제한다.
//
// CloudKit 제약을 그대로 지킨다(v4 §7.2):
//   · 전 속성이 기본값 또는 optional
//   · @Attribute(.unique) 불가
//   · 관계는 양방향 optional
// 이 제약을 어기면 CloudKit 동기화를 켜는 순간 컨테이너 초기화가 실패한다.
//
// **iOS 26 SDK의 @Model은 이니셜라이저를 직접 요구한다.** 모든 속성에 기본값이
// 있어도 매크로가 만들어 주지 않는다("@Model requires an initializer be provided").
// Phase 1의 정식 모델도 같은 요구를 받는다.

@Model final class ProbeCollection {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var coverCanvasID: String = ""
    var canvases: [ProbeCanvas]? = []

    init() {}
}

@Model final class ProbeCanvas {
    var id: UUID = UUID()
    var aspect: Int = 0
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var layoutJSON: Data = Data()
    @Attribute(.externalStorage) var renderedPNG: Data?
    var collection: ProbeCollection?

    init() {}
}

struct S2_CloudKitProbe: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ProbeCollection.createdAt) private var collections: [ProbeCollection]
    @State private var draftFolderExists = false

    var body: some View {
        NavigationStack {
            List {
                Section("모음집 \(collections.count)개") {
                    ForEach(collections) { c in
                        VStack(alignment: .leading) {
                            Text(c.name)
                            Text("캔버스 \(c.canvases?.count ?? 0)개")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("초안 폴더") {
                    Text(draftFolderExists ? "존재함" : "없음")
                    Button("초안 폴더 만들기") { makeDraftFolder() }
                    Button("다시 확인") { checkDraftFolder() }
                }
            }
            .navigationTitle("S2 프로브")
            .toolbar { Button("추가") { addSample() } }
            .onAppear { checkDraftFolder() }
        }
        // **프로브 모델은 앱 컨테이너에 싣지 않는다.** 폐기 예정 타입이 정식
        // 스키마에 끼면 첫 심사 후 스키마 동결 대상이 되고, 그때는 뺄 수 없다.
        // 컨테이너를 여기로 내려 두면 이 파일을 지우는 것만으로 정리가 끝난다.
        .modelContainer(for: [ProbeCollection.self, ProbeCanvas.self])
    }

    private func addSample() {
        let c = ProbeCollection()
        c.name = "테스트 \(Int.random(in: 100...999))"
        let canvas = ProbeCanvas()
        canvas.title = "캔버스"
        canvas.collection = c
        context.insert(c)
        context.insert(canvas)
        try? context.save()
    }

    /// **경로를 다시 짜지 않고 앱이 쓰는 것을 그대로 본다.** 여기서 리터럴을
    /// 반복하면 `appDefault`가 바뀌었을 때 프로브가 앱이 더 이상 안 쓰는 폴더를
    /// 검증하게 된다 — 통과했는데 아무것도 증명 못 한 상태가 된다.
    private var draftsURL: URL { DraftStore.appDefault.root }

    /// 초안 폴더는 **CloudKit 동기화 대상이 아니어야 한다**(v4 §6.2).
    /// 기기 A에서 만들고 기기 B에서 "없음"으로 보이는 것이 통과 기준이다.
    private func makeDraftFolder() {
        try? FileManager.default.createDirectory(at: draftsURL,
                                                 withIntermediateDirectories: true)
        try? "probe".data(using: .utf8)?
            .write(to: draftsURL.appending(path: "probe.txt"))
        checkDraftFolder()
    }

    private func checkDraftFolder() {
        draftFolderExists = FileManager.default
            .fileExists(atPath: draftsURL.appending(path: "probe.txt").path())
    }
}
