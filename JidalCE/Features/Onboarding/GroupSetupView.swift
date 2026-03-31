import SwiftUI

struct GroupSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var groupName = ""
    @State private var groupColor = Color.blue

    var body: some View {
        NavigationStack {
            List {
                Section("새 캘린더 만들기") {
                    TextField("그룹 이름", text: $groupName)
                    ColorPicker("그룹 색상", selection: $groupColor)
                    Button("새 캘린더 만들기") {
                        Task { await appState.createGroup(name: groupName, color: groupColor) }
                    }
                }

                Section("기존 캘린더 사용") {
                    if appState.availableGroups.isEmpty {
                        Text("사용 가능한 캘린더가 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("기존 일정과 가계부 기록이 함께 표시됩니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(appState.availableGroups) { group in
                            Button {
                                Task { await appState.selectExistingGroup(group) }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(cgColor: group.color))
                                        .frame(width: 12, height: 12)
                                    Text(group.name)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("그룹 설정")
        }
    }
}
