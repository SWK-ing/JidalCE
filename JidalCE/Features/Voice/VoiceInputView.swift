import SwiftUI

struct VoiceInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var manager = VoiceInputManager()
    @State private var parsedResult: AIService.ParsedResult?
    @State private var errorMessage: String?
    @State private var isPressingRecord = false
    @State private var isAutoParsing = false
    let onApply: (AIService.ParsedResult) -> Void

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
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

                    if let parsedResult {
                        ParsedResultCard(result: parsedResult)
                        Button("폼에 적용") {
                            onApply(parsedResult)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    } else if isAutoParsing {
                        ProgressView("AI 파싱 중...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer(minLength: max(geometry.size.height * 0.12, 40))

                    VStack(spacing: 8) {
                        Image(systemName: manager.isRecording ? "mic.fill" : "mic")
                            .font(.title2.bold())
                        Text(manager.isRecording ? "누르는 중 녹음" : "길게 눌러 녹음")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(manager.isRecording ? Color.red : Color.blue, in: RoundedRectangle(cornerRadius: 18))
                    .contentShape(RoundedRectangle(cornerRadius: 18))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !isPressingRecord else { return }
                                isPressingRecord = true
                                Task {
                                    do {
                                        if !manager.isRecording {
                                            try await manager.startRecording()
                                        }
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        isPressingRecord = false
                                    }
                                }
                            }
                            .onEnded { _ in
                                isPressingRecord = false
                                if manager.isRecording {
                                    manager.stopRecording()
                                }
                            }
                    )
                    .padding(.bottom, max(geometry.size.height * 0.12, 24))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding()
            }
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
            .onChange(of: manager.isRecording) { _, isRecording in
                guard !isRecording else { return }
                guard !manager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                guard appState.aiService.isConfigured else { return }
                guard parsedResult == nil else { return }
                Task {
                    await parseAndApplyIfPossible(autoApply: true)
                }
            }
        }
    }

    private func parseAndApplyIfPossible(autoApply: Bool) async {
        guard !isAutoParsing else { return }
        let text = manager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isAutoParsing = true
        defer { isAutoParsing = false }

        do {
            let result = try await appState.aiService.parseVoiceInput(text)
            parsedResult = result
            if autoApply {
                onApply(result)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
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
