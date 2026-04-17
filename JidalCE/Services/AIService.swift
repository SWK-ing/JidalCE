import Foundation

@MainActor
@Observable
final class AIService {
    enum ProviderPreset: String, CaseIterable, Identifiable, Codable {
        case openAI
        case claude
        case groq
        case gemini

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .openAI:
                return "ChatGPT"
            case .claude:
                return "Claude"
            case .groq:
                return "Groq"
            case .gemini:
                return "Gemini"
            }
        }

        var defaultEndpoint: String {
            switch self {
            case .openAI:
                return "https://api.openai.com/v1/chat/completions"
            case .claude:
                return "https://api.anthropic.com/v1/chat/completions"
            case .groq:
                return "https://api.groq.com/openai/v1/chat/completions"
            case .gemini:
                return "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"
            }
        }

        var defaultModel: String {
            switch self {
            case .openAI:
                return "gpt-4o-mini"
            case .claude:
                return "claude-sonnet-4-20250514"
            case .groq:
                return "llama-3.1-8b-instant"
            case .gemini:
                return "gemini-2.5-flash"
            }
        }
    }

    struct AIProvider: Codable, Hashable {
        var presetRawValue: String
        var endpoint: String
        var apiKey: String
        var model: String

        var preset: ProviderPreset {
            get { ProviderPreset(rawValue: presetRawValue) ?? .openAI }
            set { presetRawValue = newValue.rawValue }
        }

        var isConfigured: Bool {
            !endpoint.isEmpty && !apiKey.isEmpty && !model.isEmpty
        }

        init(
            preset: ProviderPreset = .openAI,
            endpoint: String? = nil,
            apiKey: String = "",
            model: String? = nil
        ) {
            self.presetRawValue = preset.rawValue
            self.endpoint = endpoint ?? preset.defaultEndpoint
            self.apiKey = apiKey
            self.model = model ?? preset.defaultModel
        }

        static let empty = AIProvider()

        enum CodingKeys: String, CodingKey {
            case presetRawValue
            case endpoint
            case apiKey
            case model
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let presetRawValue = try container.decodeIfPresent(String.self, forKey: .presetRawValue) ?? ProviderPreset.openAI.rawValue
            let preset = ProviderPreset(rawValue: presetRawValue) ?? .openAI
            self.presetRawValue = preset.rawValue
            self.endpoint = try container.decodeIfPresent(String.self, forKey: .endpoint) ?? preset.defaultEndpoint
            self.apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
            self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? preset.defaultModel
        }
    }

    struct ParsedResult: Codable, Hashable {
        var amount: Int?
        var category: String?
        var memo: String?
        var date: String?
        var type: String?
    }

    var provider: AIProvider = .empty
    private let promptSettingsManager = PromptSettingsManager()

    init() {
        load()
    }

    var isConfigured: Bool {
        !provider.endpoint.isEmpty && !provider.apiKey.isEmpty && !provider.model.isEmpty
    }

    func save(provider: AIProvider) {
        self.provider = provider
        guard let data = try? JSONEncoder().encode(provider) else { return }
        UserDefaults.standard.set(data, forKey: "aiProvider")
    }

    func suggestedProvider(for preset: ProviderPreset, apiKey: String? = nil, model: String? = nil) -> AIProvider {
        AIProvider(
            preset: preset,
            endpoint: preset.defaultEndpoint,
            apiKey: apiKey ?? provider.apiKey,
            model: model ?? preset.defaultModel
        )
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: "aiProvider"),
              let provider = try? JSONDecoder().decode(AIProvider.self, from: data) else {
            provider = .empty
            return
        }
        self.provider = provider
    }

    func fetchAvailableModels(for provider: AIProvider) async throws -> [String] {
        let request = try makeModelsRequest(for: provider)
        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseModels(data: data, preset: provider.preset)
    }

    func testConnection() async throws -> ParsedResult {
        try await parseVoiceInput("오늘 점심 김밥천국에서 팔천오백원")
    }

    func parseVoiceInput(_ text: String) async throws -> ParsedResult {
        let response = try await callAPI(prompt: prompt(for: .voice, input: text))
        return try parseJSON(response)
    }

    func parseSMSInput(_ text: String) async throws -> ParsedResult {
        let response = try await callAPI(prompt: prompt(for: .sms, input: text))
        return try parseJSON(response)
    }

    private func parseJSON(_ response: String) throws -> ParsedResult {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSONObject(from: cleaned)
        guard let data = jsonString.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return try JSONDecoder().decode(ParsedResult.self, from: data)
    }

    private func prompt(for type: PromptType, input: String) -> String {
        promptSettingsManager.prompt(for: type).replacingOccurrences(of: "{input}", with: input)
    }

    private func callAPI(prompt: String) async throws -> String {
        guard let url = URL(string: provider.endpoint) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": provider.model,
            "messages": [
                ["role": "system", "content": "You are a Korean financial transaction parser. Respond only in JSON."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.1,
            "max_tokens": 200,
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NSError(
                domain: "AIService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: apiErrorMessage(from: json) ?? "AI 요청 실패 (\(httpResponse.statusCode))"]
            )
        }

        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]

        if let content = message?["content"] as? String, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }

        if let contentParts = message?["content"] as? [[String: Any]] {
            let text = contentParts
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }

        throw NSError(
            domain: "AIService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: apiErrorMessage(from: json) ?? "AI 응답에서 파싱 결과를 찾지 못했습니다."]
        )
    }

    private func makeModelsRequest(for provider: AIProvider) throws -> URLRequest {
        guard !provider.apiKey.isEmpty else {
            throw URLError(.userAuthenticationRequired)
        }

        switch provider.preset {
        case .openAI:
            return try bearerRequest(urlString: "https://api.openai.com/v1/models", apiKey: provider.apiKey)
        case .groq:
            return try bearerRequest(urlString: "https://api.groq.com/openai/v1/models", apiKey: provider.apiKey)
        case .claude:
            guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(provider.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            return request
        case .gemini:
            guard var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
                throw URLError(.badURL)
            }
            components.queryItems = [URLQueryItem(name: "key", value: provider.apiKey)]
            guard let url = components.url else {
                throw URLError(.badURL)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            return request
        }
    }

    private func bearerRequest(urlString: String, apiKey: String) throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func parseModels(data: Data, preset: ProviderPreset) throws -> [String] {
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        switch preset {
        case .openAI, .groq, .claude:
            let models: [String] = (object?["data"] as? [[String: Any]])?
                .compactMap { $0["id"] as? String } ?? []
            return models.sorted()
        case .gemini:
            let models: [String] = (object?["models"] as? [[String: Any]])?
                .compactMap { item in
                    let methods = item["supportedGenerationMethods"] as? [String] ?? []
                    guard methods.contains("generateContent") else { return nil }
                    if let baseModel = item["baseModelId"] as? String {
                        return baseModel
                    }
                    let name = item["name"] as? String
                    return name?.replacingOccurrences(of: "models/", with: "")
                } ?? []
            return Array(Set<String>(models)).sorted()
        }
    }

    private func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```") {
            let lines = trimmed.components(separatedBy: .newlines)
            let filtered = lines.filter { !$0.hasPrefix("```") }
            let joined = filtered.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if joined.first == "{", joined.last == "}" {
                return joined
            }
        }

        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start...end])
        }

        return trimmed
    }

    private func apiErrorMessage(from object: [String: Any]?) -> String? {
        if let error = object?["error"] as? [String: Any] {
            return (error["message"] as? String) ?? (error["type"] as? String)
        }
        if let message = object?["message"] as? String {
            return message
        }
        return nil
    }
}
