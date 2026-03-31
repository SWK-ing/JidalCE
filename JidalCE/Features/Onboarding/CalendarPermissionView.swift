import SwiftUI

struct CalendarPermissionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
            Text("캘린더 권한이 필요합니다")
                .font(.title2.bold())
            Text("가계부 데이터를 캘린더 이벤트로 저장하고 공유 캘린더와 동기화합니다.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("캘린더 권한 허용") {
                Task { await appState.requestCalendarAccess() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
