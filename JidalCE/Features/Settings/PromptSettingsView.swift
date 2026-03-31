import SwiftUI

struct PromptSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var editingType: PromptType?

    var body: some View {
        List {
            Section("프롬프트") {
                ForEach(PromptType.allCases) { type in
                    Button {
                        editingType = type
                    } label: {
                        HStack {
                            Text(type.rawValue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button("전체 초기화", role: .destructive) {
                    appState.promptSettingsManager.resetAll()
                }
            }
        }
        .navigationTitle("프롬프트 편집")
        .sheet(item: $editingType) { type in
            PromptEditorSheet(type: type)
                .environment(appState)
        }
    }
}

private struct PromptEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var prompt = ""
    let type: PromptType

    var body: some View {
        NavigationStack {
            TextEditor(text: $prompt)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                .padding()
                .navigationTitle(type.rawValue)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("초기화") {
                            appState.promptSettingsManager.reset(type: type)
                            prompt = appState.promptSettingsManager.prompt(for: type)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            appState.promptSettingsManager.save(prompt: prompt, for: type)
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    prompt = appState.promptSettingsManager.prompt(for: type)
                }
        }
    }
}
