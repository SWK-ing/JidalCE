import SwiftUI

struct AISettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedPreset: AIService.ProviderPreset = .openAI
    @State private var endpoint = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var availableModels: [String] = []
    @State private var isLoadingModels = false
    @State private var testMessage: String?

    var body: some View {
        Form {
            Section("AI 설정") {
                Picker("공급자", selection: $selectedPreset) {
                    ForEach(AIService.ProviderPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                TextField("API 엔드포인트", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                SecureField("API 키", text: $apiKey)

                if availableModels.isEmpty {
                    TextField("모델명", text: $model)
                        .textInputAutocapitalization(.never)
                } else {
                    Picker("모델", selection: $model) {
                        ForEach(availableModels, id: \.self) { modelName in
                            Text(modelName).tag(modelName)
                        }
                    }
                }
            }

            Section {
                Button(isLoadingModels ? "모델 불러오는 중..." : "모델 목록 불러오기") {
                    Task { await loadModels() }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoadingModels)

                Button("연결 테스트") {
                    Task {
                        do {
                            appState.aiService.save(provider: currentProvider)
                            _ = try await appState.aiService.testConnection()
                            testMessage = "연결 성공"
                        } catch {
                            testMessage = error.localizedDescription
                        }
                    }
                }

                Button("저장") {
                    Task {
                        appState.aiService.save(provider: currentProvider)
                        await loadModels()
                        testMessage = "저장 완료"
                    }
                }
            }

            if let testMessage {
                Section("상태") {
                    Text(testMessage)
                }
            }
        }
        .navigationTitle("AI 설정")
        .onAppear {
            let provider = appState.aiService.provider
            selectedPreset = provider.preset
            endpoint = provider.endpoint
            apiKey = provider.apiKey
            model = provider.model
            if provider.isConfigured {
                Task { await loadModels() }
            }
        }
        .onChange(of: selectedPreset) { _, newPreset in
            let suggested = appState.aiService.suggestedProvider(
                for: newPreset,
                apiKey: apiKey,
                model: model
            )
            endpoint = suggested.endpoint
            if availableModels.isEmpty || !availableModels.contains(model) {
                model = suggested.model
            }
            availableModels = []
        }
    }

    private var currentProvider: AIService.AIProvider {
        AIService.AIProvider(
            preset: selectedPreset,
            endpoint: endpoint,
            apiKey: apiKey,
            model: model
        )
    }

    private func loadModels() async {
        isLoadingModels = true
        defer { isLoadingModels = false }

        do {
            let models = try await appState.aiService.fetchAvailableModels(for: currentProvider)
            availableModels = models
            if !models.contains(model), let first = models.first {
                model = first
            }
            if models.isEmpty {
                testMessage = "사용 가능한 모델을 찾지 못했습니다."
            }
        } catch {
            availableModels = []
            testMessage = "모델 목록 불러오기 실패: \(error.localizedDescription)"
        }
    }
}
