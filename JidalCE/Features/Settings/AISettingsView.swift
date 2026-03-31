import SwiftUI

struct AISettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var endpoint = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var testMessage: String?

    var body: some View {
        Form {
            Section("AI 설정") {
                TextField("API 엔드포인트", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                SecureField("API 키", text: $apiKey)
                TextField("모델명", text: $model)
                    .textInputAutocapitalization(.never)
            }

            Section {
                Button("연결 테스트") {
                    Task {
                        do {
                            appState.aiService.save(provider: .init(endpoint: endpoint, apiKey: apiKey, model: model))
                            _ = try await appState.aiService.testConnection()
                            testMessage = "연결 성공"
                        } catch {
                            testMessage = error.localizedDescription
                        }
                    }
                }
                Button("저장") {
                    appState.aiService.save(provider: .init(endpoint: endpoint, apiKey: apiKey, model: model))
                    testMessage = "저장 완료"
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
            endpoint = provider.endpoint
            apiKey = provider.apiKey
            model = provider.model
        }
    }
}
