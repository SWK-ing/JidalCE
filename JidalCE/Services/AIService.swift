import Observation
import Foundation

@MainActor
@Observable
final class AIService {
    struct AIProvider: Codable, Hashable {
        var endpoint: String
        var apiKey: String
        var model: String

        static let empty = AIProvider(endpoint: "https://api.openai.com/v1/chat/completions", apiKey: "", model: "gpt-4o-mini")
    }

    struct ParsedResult: Codable, Hashable {
        var amount: Int?
        var category: String?
        var memo: String?
        var date: String?
        var type: String?
    }

    var provider: AIProvider = .empty

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

    func load() {
        guard let data = UserDefaults.standard.data(forKey: "aiProvider"),
              let provider = try? JSONDecoder().decode(AIProvider.self, from: data) else {
            provider = .empty
            return
        }
        self.provider = provider
    }

    func testConnection() async throws -> ParsedResult {
        try await parseVoiceInput("오늘 점심 김밥천국에서 팔천오백원")
    }

    func parseVoiceInput(_ text: String) async throws -> ParsedResult {
        let response = try await callAPI(prompt: voicePrompt(text))
        return try parseJSON(response)
    }

    func parseSMSInput(_ text: String) async throws -> ParsedResult {
        let response = try await callAPI(prompt: smsPrompt(text))
        return try parseJSON(response)
    }

    private func parseJSON(_ response: String) throws -> ParsedResult {
        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return try JSONDecoder().decode(ParsedResult.self, from: data)
    }

    private func voicePrompt(_ text: String) -> String {
        """
        다음 한국어 텍스트에서 가계부 거래 정보를 추출하세요.

        텍스트: "\(text)"

        아래 JSON 형식으로만 응답하세요:
        {
          "amount": 숫자(양수),
          "type": "지출" 또는 "수입",
          "category": "식비/교통/생활/문화/의료/교육/의류/미용/통신/보험/급여/용돈/이자/기타" 중 하나,
          "memo": "간단한 설명",
          "date": "오늘/어제/M월d일 형식"
        }
        """
    }

    private func smsPrompt(_ text: String) -> String {
        """
        다음 카드 결제 SMS에서 거래 정보를 추출하세요.

        SMS: "\(text)"

        아래 JSON 형식으로만 응답하세요:
        {
          "amount": 숫자(양수),
          "type": "지출" 또는 "수입",
          "category": "식비/교통/생활/문화/의료/교육/의류/미용/통신/보험/급여/용돈/이자/기타" 중 하나,
          "memo": "가맹점명",
          "date": "M/dd" 또는 "M월d일"
        }
        """
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
            "max_tokens": 200
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        return message?["content"] as? String ?? ""
    }
}
