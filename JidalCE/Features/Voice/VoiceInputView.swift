import SwiftUI

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var manager = VoiceInputManager()
    @State private var parsedResult: AIService.ParsedResult?
    @State private var errorMessage: String?
    let onApply: (AIService.ParsedResult) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: manager.isRecording ? "mic.circle.fill" : "mic.circle")
                    .font(.system(size: 72))
                    .foregroundStyle(manager.isRecording ? .red : .blue)

                Text(manager.isRecording ? "녹음 중..." : "음성 입력")
                    .font(.title3.bold())

                Text(manager.transcribedText.isEmpty ? "음성을 인식하면 여기에 표시됩니다." : manager.transcribedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                HStack {
                    Button(manager.isRecording ? "중지" : "녹음 시작") {
                        Task {
                            do {
                                if manager.isRecording {
                                    manager.stopRecording()
                                } else {
                                    try await manager.startRecording()
                                }
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("AI 파싱") {
                        Task {
                            do {
                                parsedResult = try await appState.aiService.parseVoiceInput(manager.transcribedText)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(manager.transcribedText.isEmpty || !appState.aiService.isConfigured)
                }

                if let parsedResult {
                    ParsedResultCard(result: parsedResult)
                    Button("폼에 적용") {
                        onApply(parsedResult)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("음성 입력")
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

private struct ParsedResultCard: View {
    let result: AIService.ParsedResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI 파싱 결과")
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
