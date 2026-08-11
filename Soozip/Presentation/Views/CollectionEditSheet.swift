import SwiftUI

/// 모음집 생성·이름 변경 시트.
///
/// 길이 제한을 여기서 다시 검사하지 않는다 — 리포지토리가 거부하고, 그 거부가
/// UI 이전의 최후 방어선이다(Phase 1). 시트는 입력을 모아 넘기고 결과를 받는다.
struct CollectionEditSheet: View {

    enum Mode: Equatable {
        case create
        case rename(current: String)

        var title: String {
            switch self {
            case .create: return "새 모음집"
            case .rename: return "이름 변경"
            }
        }
    }

    let mode: Mode
    /// 이름을 확정한다. 던지면 시트가 열린 채로 메시지를 보여준다 —
    /// 거부된 입력에서 시트를 닫아 버리면 사용자가 무엇이 잘못됐는지 못 본다.
    let onSubmit: (String) throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var errorMessage: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("모음집 이름", text: $name)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(submit)
                } footer: {
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    } else {
                        Text("1~20자. 같은 이름을 여러 번 써도 됩니다.")
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료", action: submit)
                }
            }
            .onAppear {
                if case .rename(let current) = mode { name = current }
                focused = true
            }
        }
    }

    private func submit() {
        do {
            try onSubmit(name)
            dismiss()
        } catch let error as RepositoryError {
            errorMessage = Self.message(for: error)
        } catch {
            errorMessage = "저장하지 못했습니다."
        }
    }

    /// 에러 케이스가 맥락(무엇이 몇 자였는지)을 들고 있어서 문구를 만들 수 있다.
    private static func message(for error: RepositoryError) -> String {
        switch error {
        case .collectionNameOutOfRange(let length, let allowed):
            return length < allowed.lowerBound
                ? "이름을 입력해주세요."
                : "이름은 \(allowed.upperBound)자까지예요. 지금 \(length)자입니다."
        case .canvasTitleOutOfRange, .canvasNotInCollection:
            return "저장하지 못했습니다."
        }
    }
}
