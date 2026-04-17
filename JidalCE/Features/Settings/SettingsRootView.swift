import SwiftUI

struct SettingsRootView: View {
    @Environment(AppState.self) private var appState
    @State private var newCategory = ""
    @State private var authorName = ""

    var body: some View {
        List {
            Section("기본 설정") {
                TextField("작성자 이름", text: Binding(
                    get: { authorName.isEmpty ? appState.categoryManager.authorName : authorName },
                    set: { authorName = $0 }
                ))
                Button("작성자 저장") {
                    appState.categoryManager.updateAuthorName(authorName)
                }
            }

            Section("이동") {
                NavigationLink("그룹 관리") { GroupManagementView() }
                NavigationLink("가계부 관리") { LedgerManagementView() }
                NavigationLink("최근 변경 이력") { HistoryView() }
                NavigationLink("장부정리") { BookClosingView() }
                NavigationLink("예산 관리") { BudgetSettingsView() }
                NavigationLink("AI 설정") { AISettingsView() }
                NavigationLink("프롬프트 편집") { PromptSettingsView() }
                NavigationLink("거래 검색") { TransactionSearchView() }
            }

            Section("카테고리") {
                HStack {
                    TextField("새 카테고리", text: $newCategory)
                    Button("추가") {
                        appState.categoryManager.addCategory(newCategory)
                        newCategory = ""
                    }
                }
                ForEach(appState.categoryManager.categories, id: \.self) { category in
                    Text(category)
                }
                .onDelete { appState.categoryManager.removeCategories(at: $0) }
                .onMove { appState.categoryManager.moveCategories(from: $0, to: $1) }
            }
        }
        .navigationTitle("설정")
        .toolbar {
            EditButton()
        }
    }
}
