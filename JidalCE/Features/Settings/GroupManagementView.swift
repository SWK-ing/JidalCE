import SwiftUI

struct GroupManagementView: View {
    @Environment(AppState.self) private var appState
    @State private var showingDeleteAlert = false
    @State private var editedName = ""

    var body: some View {
        List {
            if let group = appState.selectedGroup {
                Section("현재 그룹") {
                    TextField("그룹 이름", text: Binding(
                        get: { editedName.isEmpty ? group.name : editedName },
                        set: { editedName = $0 }
                    ))
                    Button("이름 저장") {
                        Task { await appState.renameCurrentGroup(to: editedName.isEmpty ? group.name : editedName) }
                    }
                    Button("그룹 삭제", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
                Section("공유") {
                    NavigationLink("캘린더 공유 안내") {
                        SharingGuideView(groupName: group.name)
                    }
                }
            }
            Section("공유 안내") {
                Text("설정 > 캘린더에서 해당 캘린더를 공유하면 다른 가족 구성원과 함께 사용할 수 있습니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("그룹 관리")
        .alert("이 그룹의 모든 가계부와 거래 기록이 삭제됩니다.", isPresented: $showingDeleteAlert) {
            Button("삭제", role: .destructive) {
                Task { await appState.deleteCurrentGroup() }
            }
            Button("취소", role: .cancel) {}
        }
    }
}
