import SwiftUI

struct BookClosingView: View {
    @Environment(AppState.self) private var appState
    @State private var startDate = Date()

    var body: some View {
        Form {
            if let ledgerName = appState.selectedLedgerName {
                Section("가계부") {
                    Text(ledgerName)
                }
            }
            if let firstDate = appState.firstRecordDate() {
                Section("가이드") {
                    Text("가장 오래된 기록: \(firstDate.koreanDisplayDate)")
                }
                .onAppear {
                    startDate = firstDate
                }
            }

            Section("정리 범위") {
                DatePicker("정리 시작일", selection: $startDate, displayedComponents: .date)
                Text("정리 종료일: \(appState.bookClosingEndMonthText)")
                Text("정리 종료일은 전전월로 자동 적용됩니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("장부정리 시작") {
                    Task { await appState.rebuildSnapshots(startingFrom: startDate) }
                }
                .disabled(appState.isBookClosingInProgress)
            }

            if appState.isBookClosingInProgress || !appState.bookClosingProgressMonths.isEmpty {
                Section("진행 상태") {
                    if appState.isBookClosingInProgress {
                        ProgressView("장부정리 진행 중...")
                    }
                    ForEach(appState.bookClosingProgressMonths, id: \.self) { month in
                        Text("\(month) ✓")
                    }
                    if let result = appState.bookClosingResultText {
                        Text(result)
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle("장부정리")
    }
}
