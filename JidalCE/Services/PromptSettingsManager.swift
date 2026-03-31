import Foundation

enum PromptType: String, CaseIterable, Hashable, Identifiable {
    case voice = "음성 입력 파싱"
    case sms = "SMS 파싱"

    var id: String { rawValue }
}

struct PromptSettingsManager {
    func prompt(for type: PromptType) -> String {
        UserDefaults.standard.string(forKey: key(for: type)) ?? defaultPrompt(for: type)
    }

    func save(prompt: String, for type: PromptType) {
        UserDefaults.standard.set(prompt, forKey: key(for: type))
    }

    func reset(type: PromptType) {
        UserDefaults.standard.removeObject(forKey: key(for: type))
    }

    func resetAll() {
        PromptType.allCases.forEach(reset(type:))
    }

    func defaultPrompt(for type: PromptType) -> String {
        switch type {
        case .voice:
            return """
            다음 한국어 텍스트에서 가계부 거래 정보를 추출하세요.

            텍스트: "{input}"

            아래 JSON 형식으로만 응답하세요:
            {
              "amount": 숫자(양수),
              "type": "지출" 또는 "수입",
              "category": "식비/교통/생활/문화/의료/교육/의류/미용/통신/보험/급여/용돈/이자/기타" 중 하나,
              "memo": "간단한 설명",
              "date": "오늘/어제/M월d일 형식"
            }
            """
        case .sms:
            return """
            다음 카드 결제 SMS에서 거래 정보를 추출하세요.

            SMS: "{input}"

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
    }

    private func key(for type: PromptType) -> String {
        "prompt_\(type.rawValue)"
    }
}
