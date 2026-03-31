import SwiftUI

struct SMSInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var smsText = ""
    @State private var parsedResult: AIService.ParsedResult?
    @State private var errorMessage: String?
    let onApply: (AIService.ParsedResult) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextEditor(text: $smsText)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                Button("파싱하기") {
                    Task {
                        do {
                            parsedResult = try await appState.aiService.parseSMSInput(smsText)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(smsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !appState.aiService.isConfigured)

                if let parsedResult {
                    ParsedSMSResultCard(result: parsedResult)
                    Button("폼에 적용") {
                        onApply(parsedResult)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("SMS 거래 입력")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .alert("안내", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("확인", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

private struct ParsedSMSResultCard: View {
    let result: AIService.ParsedResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("파싱 결과")
                .font(.headline)
            Text("금액: \(result.amount?.wonString ?? "-")")
            Text("구분: \(result.type ?? "-")")
            Text("카테고리: \(result.category ?? "-")")
            Text("메모: \(result.memo ?? "-")")
            Text("날짜: \(result.date ?? "-")")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
