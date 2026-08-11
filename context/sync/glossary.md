# sync 용어 사전

| 용어 | 설명 |
|------|------|
| SwiftData | iOS 17+ 영속성 프레임워크. `@Model` 매크로로 정의한다 |
| CloudKit | 애플의 iCloud 백엔드. 사용자 계정으로 기기 간 동기화된다 |
| CKAsset | CloudKit의 대용량 바이너리 저장 타입. `.externalStorage` 속성이 여기로 간다 |
| `.externalStorage` | 큰 `Data`를 DB 파일 밖에 두는 SwiftData 속성 옵션 |
| additive-only | 첫 심사 이후 CloudKit 스키마에 **추가만** 가능하고 변경·삭제는 불가한 제약 |
| 스키마 동결 | 첫 심사 전에 모델을 확정하는 것. 이후에는 되돌릴 수 없다 |
| 로컬 모드 | iCloud 미로그인·용량 초과 시 동기화 없이 기기 안에서만 동작하는 격하 상태 |
| last-write-wins (LWW) | 충돌 시 나중에 쓴 쪽이 이기는 정책. 병합하지 않는다 |
| `Drafts/` | `Application Support` 아래 초안 폴더. **CloudKit 동기화 대상이 아니다** |
| 고아 초안 | 소속 모음집이 없거나 7일 이상 방치된 `Drafts/` 폴더 |
| 백업 zip | 앱 데이터를 zip으로 내보내고 가져오는 기능 (P0.5) |
| `SoozipSchema` | 모델 목록의 SSOT. 앱 배선·테스트 컨테이너·스키마 검사가 같은 배열을 본다 — 세 곳이 각자 들면 한 곳만 빠졌을 때 관계가 런타임에 깨진다 |
| `deleteRule: .cascade` | 부모를 지우면 자식도 지우는 관계 선언. **AC-16·17을 지탱하는 유일한 계약**이라 수동 정리 경로를 두지 않는다 |
| 역관계 단일 선언 | `@Relationship(inverse:)`를 관계의 **한쪽에만** 다는 규칙. 양쪽에 달면 스키마 구성에서 죽는다 |
