import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            if appState.recentHistory.isEmpty {
                EmptyStateView(title: "이력 없음", message: "최근 변경 이력이 없습니다.", systemImage: "clock.arrow.circlepath")
                    .frame(height: 260)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(appState.recentHistory) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(entry.date) \(entry.time) \(entry.action.rawValue)")
                            .font(.headline)
                        Text("\(entry.memo) \(entry.amount)")
                        Text(entry.by)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("이전 이력은 캘린더 앱에서 히스토리 이벤트를 확인하세요")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .navigationTitle("최근 변경 이력")
    }
}
