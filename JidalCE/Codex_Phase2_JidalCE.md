# Codex Task: Jidal CE — Phase 2: 확장 기능

## 현재 상태

Phase 1 MVP 완성. 빌드 성공, 워닝 0건. EventKit 기반 거래 CRUD, 스냅샷, 히스토리, 장부정리, 4탭 UI가 모두 동작한다. 이번 Phase 2에서는 통계 시각화, 음성/SMS 입력, 예산 관리, 가계부 메타데이터를 추가한다.

---

## 기술 스택 추가

- **Swift Charts** (iOS 16+ 내장, import Charts)
- **Speech** 프레임워크 (음성 인식, import Speech)
- **AI 파싱**: 외부 LLM API 호출 (설정 가능한 엔드포인트)
- 여전히 SPM 외부 패키지 없음

---

## Task 1: 통계 차트 (Swift Charts)

현재 통계 탭의 텍스트 기반 합계를 차트로 교체/보강한다.

### 1-1. 월간 지출/수입 흐름 바 차트

```
┌─────────────────────────────┐
│  월간 흐름                    │
│                             │
│  ██ 지출  ░░ 수입            │
│                             │
│  1월  ██████░░░░             │
│  2월  ████████░░░            │
│  3월  █████░░░░░░            │
│  4월  ███░░░░                │
│                             │
└─────────────────────────────┘
```

```swift
import Charts

struct MonthlyFlowChart: View {
    let data: [MonthlyFlowData]  // month, expense, income
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("월", item.month),
                y: .value("금액", abs(item.expense))
            )
            .foregroundStyle(.red.opacity(0.7))
            
            BarMark(
                x: .value("월", item.month),
                y: .value("금액", item.income)
            )
            .foregroundStyle(.blue.opacity(0.7))
        }
    }
}
```

데이터 범위: 최근 6개월. 스냅샷에서 월별 수입/지출 가져오고, 라이브 기간(전월+당월)은 직접 계산.

### 1-2. 카테고리별 파이 차트

```swift
struct CategoryPieChart: View {
    let data: [CategoryAmount]  // category, amount
    
    var body: some View {
        Chart(data) { item in
            SectorMark(
                angle: .value("금액", item.amount),
                innerRadius: .ratio(0.5),  // 도넛 스타일
                angularInset: 1.5
            )
            .foregroundStyle(by: .value("카테고리", item.category))
        }
    }
}
```

지출/수입 각각 별도 파이 차트 또는 세그먼트로 전환.

### 1-3. 통계 탭 최종 레이아웃

```
┌─────────────────────────────┐
│  [◀ 3월]    4월    [5월 ▶]  │  ← 월 전환
├─────────────────────────────┤
│                             │
│  잔액: 2,500,000원           │
│  지출: 350,000원             │
│  수입: 5,000,000원           │
│                             │
│  ── 월간 흐름 ──             │
│  [바 차트: 최근 6개월]        │
│                             │
│  ── 지출 카테고리 ──          │
│  [파이 차트]                 │
│  식비 34% · 교통 24% · ...   │
│                             │
│  ── 수입 카테고리 ──          │
│  [파이 차트]                 │
│  급여 90% · 이자 10%         │
│                             │
│  ── 예산 ──                  │
│  [예산 진행 바]               │
│                             │
└─────────────────────────────┘
```

---

## Task 2: 예산 관리

### 데이터 모델

```swift
struct Budget {
    var monthlyLimit: Int           // 월 총 예산 (0이면 미설정)
    var categoryLimits: [String: Int]  // 카테고리별 예산 (선택)
}
```

UserDefaults에 JSON으로 저장. 가계부별로 분리: `budget_{가계부명}`

### 예산 설정 화면

```
설정 → 예산 관리

  월 총 예산: [ 500,000 ]원

  카테고리별 (선택):
    식비:    [ 150,000 ]원
    교통:    [  80,000 ]원
    ...
    
  [ 저장 ]
```

### 예산 진행 표시 (통계 탭 하단)

```
── 예산 ──
전체: 350,000 / 500,000원  (70%)
  ████████████████░░░░░░

식비: 120,000 / 150,000원  (80%)  ⚠️
  ████████████████████░░

교통: 85,000 / 80,000원  (106%)  🔴 초과
  ██████████████████████████
```

80% 이상: 경고(⚠️), 100% 초과: 초과(🔴)

### 예산 알림 (선택)

예산 80% 도달 시 앱 내 배너 알림. 로컬 알림(UNUserNotificationCenter)은 Phase 3으로 미룸.

---

## Task 3: 음성 입력

### 흐름

```
거래 추가 화면 → 🎙 마이크 버튼 탭
  → 음성 인식 시작 (Speech 프레임워크)
  → 사용자 발화: "오늘 점심 김밥천국에서 팔천오백원"
  → 텍스트 변환: "오늘 점심 김밥천국에서 팔천오백원"
  → AI 파싱 API 호출
  → 파싱 결과: { amount: -8500, category: "식비", memo: "점심 김밥천국", date: "오늘" }
  → 거래 추가 폼에 자동 채움
  → 사용자 확인 후 저장
```

### Speech 프레임워크 권한

Info.plist:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>음성으로 거래를 기록하기 위해 음성 인식을 사용합니다.</string>
<key>NSMicrophoneUsageDescription</key>
<string>음성으로 거래를 기록하기 위해 마이크를 사용합니다.</string>
```

### 음성 인식 구현

```swift
import Speech

class VoiceInputManager: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var transcribedText = ""
    @Published var isRecording = false
    
    func startRecording() async throws {
        // 권한 요청
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard authStatus == .authorized else { return }
        
        // 오디오 세션 설정
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                self?.transcribedText = result.bestTranscription.formattedString
            }
            if error != nil || (result?.isFinal ?? false) {
                self?.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        isRecording = false
    }
}
```

### 음성 입력 UI

```
┌─────────────────────────────┐
│  음성 입력                    │
├─────────────────────────────┤
│                             │
│        🎙                   │
│     (녹음 중...)             │
│                             │
│  "오늘 점심 김밥천국에서      │
│   팔천오백원"                 │
│                             │
│  [ 중지 ]    [ 다시 ]        │
│                             │
│  ── AI 파싱 결과 ──          │
│  금액: 8,500원 (지출)        │
│  카테고리: 식비               │
│  메모: 점심 김밥천국           │
│  날짜: 오늘                  │
│                             │
│  [ 수정 ]    [ 저장 ]        │
│                             │
└─────────────────────────────┘
```

---

## Task 4: AI 파싱 서비스

음성 텍스트와 SMS 텍스트를 거래 데이터로 변환하는 AI 서비스.

### AIService 구현

```swift
class AIService: ObservableObject {
    @Published var provider: AIProvider = .loaded()  // UserDefaults에서 로드
    
    struct AIProvider: Codable {
        var endpoint: String    // "https://api.openai.com/v1/chat/completions"
        var apiKey: String      // API 키
        var model: String       // "gpt-4o-mini" 또는 커스텀 모델명
    }
    
    struct ParsedResult {
        var amount: Int?
        var category: String?
        var memo: String?
        var date: String?       // "오늘", "어제", "3/15" 등
        var type: String?       // "지출" or "수입"
    }
    
    func parseVoiceInput(_ text: String) async throws -> ParsedResult {
        let prompt = voicePrompt(text)
        let response = try await callAPI(prompt: prompt)
        return parseJSON(response)
    }
    
    func parseSMSInput(_ text: String) async throws -> ParsedResult {
        let prompt = smsPrompt(text)
        let response = try await callAPI(prompt: prompt)
        return parseJSON(response)
    }
}
```

### AI 프롬프트 (음성)

```
다음 한국어 텍스트에서 가계부 거래 정보를 추출하세요.

텍스트: "{사용자 발화}"

아래 JSON 형식으로만 응답하세요. 다른 텍스트 없이 JSON만:
{
  "amount": 숫자(양수),
  "type": "지출" 또는 "수입",
  "category": "식비/교통/생활/문화/의료/교육/의류/미용/통신/보험/급여/용돈/이자/기타" 중 하나,
  "memo": "간단한 설명",
  "date": "오늘/어제/M월d일 형식"
}

규칙:
- 금액이 명확하지 않으면 amount를 null로
- 날짜 언급이 없으면 "오늘"
- 카테고리를 추정할 수 없으면 "기타"
- "오늘", "어제", "그제" 등 상대 날짜는 그대로 반환
```

### AI 프롬프트 (SMS)

```
다음 카드 결제 SMS에서 거래 정보를 추출하세요.

SMS: "{문자 내용}"

아래 JSON 형식으로만 응답하세요:
{
  "amount": 숫자(양수),
  "type": "지출" 또는 "수입",
  "category": "식비/교통/생활/문화/의료/교육/의류/미용/통신/보험/급여/용돈/이자/기타" 중 하나,
  "memo": "가맹점명",
  "date": "M/dd" 또는 "M월d일"
}
```

### API 호출

```swift
func callAPI(prompt: String) async throws -> String {
    let url = URL(string: provider.endpoint)!
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
    
    // OpenAI 호환 응답 파싱
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let choices = json?["choices"] as? [[String: Any]]
    let message = choices?.first?["message"] as? [String: Any]
    return message?["content"] as? String ?? ""
}
```

### 날짜 해석 (ParsedTransactionDateResolver)

```swift
func resolveDate(_ dateStr: String?) -> Date {
    guard let dateStr = dateStr else { return Date() }
    
    switch dateStr {
    case "오늘": return Date()
    case "어제": return Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    case "그제", "그저께": return Calendar.current.date(byAdding: .day, value: -2, to: Date())!
    default:
        // "3/15", "3월15일" 등 파싱 시도
        // 년도 없으면 현재 연도 사용
        return parseKoreanDate(dateStr) ?? Date()
    }
}
```

### AI 설정 화면

```
설정 → AI 설정

  API 엔드포인트: [ https://api.openai.com/v1/chat/completions ]
  API 키:        [ sk-... ]
  모델명:        [ gpt-4o-mini ]
  
  [ 연결 테스트 ]
  [ 저장 ]
```

UserDefaults에 저장. 미설정 시 음성/SMS 입력 버튼 비활성화.

---

## Task 5: SMS 파싱 입력

### 흐름

```
거래 추가 화면 → 💬 SMS 버튼 탭
  → SMS 텍스트 입력 화면 (붙여넣기)
  → 사용자가 문자 내용 붙여넣기
  → AI 파싱 호출
  → 파싱 결과 표시
  → 확인 후 저장
```

### SMS 입력 UI

```
┌─────────────────────────────┐
│  SMS 거래 입력                │
├─────────────────────────────┤
│                             │
│  카드 결제 문자를 붙여넣으세요 │
│                             │
│  ┌───────────────────────┐  │
│  │ [신한] 12/15 12:30    │  │
│  │ 8,500원 결제           │  │
│  │ 김밥천국 강남점         │  │
│  │ 누적 1,234,567원       │  │
│  └───────────────────────┘  │
│                             │
│  [ 파싱하기 ]                │
│                             │
│  ── 파싱 결과 ──             │
│  금액: 8,500원 (지출)        │
│  카테고리: 식비               │
│  메모: 김밥천국 강남점         │
│  날짜: 12월 15일             │
│                             │
│  [ 수정 ]    [ 저장 ]        │
│                             │
└─────────────────────────────┘
```

---

## Task 6: 가계부 메타데이터 (아이콘, 색상)

### __meta_ 이벤트 활용

Phase 1에서 정의된 `__meta_{가계부명}__` 이벤트를 실제로 생성/편집.

```
아이콘: 💰
색상: blue
통화: KRW
생성일: 2024-01-15
──────────
#meta:생활비
```

### LedgerRepository 보강

```swift
func createLedgerMeta(name: String, icon: String, color: String, currency: String)
func updateLedgerMeta(name: String, icon: String?, color: String?)
func fetchLedgerMeta(name: String) -> LedgerMeta?
```

### 가계부 편집 화면

```
가계부 편집

  이름:    [ 생활비 ]
  아이콘:  [ 💰 ▼ ]    ← 이모지 피커 또는 프리셋
  색상:    [ 🔵 ▼ ]    ← 7색 프리셋
  통화:    KRW (변경 불가)
  
  [ 저장 ]
```

### 색상 프리셋

```swift
enum LedgerColor: String, CaseIterable {
    case red, orange, yellow, green, blue, purple, pink
    
    var uiColor: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
}
```

### 아이콘 프리셋

```swift
let ledgerIcons = ["💰", "🏠", "✈️", "🚗", "🎓", "💊", "🛒", "👶", "🐶", "🎮", "📱", "💳"]
```

### UI 반영

가계부 선택 드롭다운, 달력 탭, 목록 탭에서 가계부 아이콘과 색상 표시.

---

## Task 7: 가계부 순서 변경

### 순서 저장

UserDefaults에 가계부 이름 배열로 저장: `ledgerOrder_{그룹ID}`

```swift
// CategoryManager처럼 관리
class LedgerOrderManager {
    func orderedLedgers(for groupId: String) -> [String]
    func updateOrder(for groupId: String, names: [String])
}
```

### UI

```
설정 → 가계부 관리 → EditButton

  ≡ 💰 생활비
  ≡ ✈️ 여행경비
  ≡ 🐶 반려동물
  
  (드래그로 순서 변경)
```

SwiftUI `List` + `.onMove` 사용.

---

## Task 8: 거래 추가 화면 통합

음성/SMS 버튼을 거래 추가 화면에 통합:

```
┌─────────────────────────────┐
│  거래 추가                    │
├─────────────────────────────┤
│                             │
│  [ 🎙 음성 ]  [ 💬 SMS ]    │  ← 상단에 입력 방법 버튼
│                             │
│  ── 수동 입력 ──             │
│                             │
│  금액:    [ 8,500 ]원        │
│  구분:    ● 지출  ○ 수입     │
│  카테고리: [ 식비 ▼ ]         │
│  메모:    [ 점심 김밥천국 ]    │
│  날짜:    [ 4월 1일 ▼ ]      │
│  가계부:  [ 💰 생활비 ▼ ]     │
│                             │
│  [ 취소 ]      [ 저장 ]      │
│                             │
└─────────────────────────────┘
```

음성/SMS 파싱 결과는 수동 입력 폼에 자동 채움. 사용자가 확인/수정 후 저장.

---

## 권한 추가 (Info.plist)

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>음성으로 거래를 기록하기 위해 음성 인식을 사용합니다.</string>

<key>NSMicrophoneUsageDescription</key>
<string>음성으로 거래를 기록하기 위해 마이크를 사용합니다.</string>
```

---

## 새 파일 목록

```
Features/
├── Voice/
│   ├── VoiceInputView.swift
│   └── VoiceInputManager.swift
├── SMS/
│   └── SMSInputView.swift
├── Statistics/
│   ├── StatisticsView.swift          (기존 수정)
│   ├── MonthlyFlowChart.swift
│   └── CategoryPieChart.swift
├── Settings/
│   ├── AISettingsView.swift
│   ├── BudgetSettingsView.swift
│   └── LedgerEditView.swift

Services/
├── AIService.swift
├── ParsedTransactionDateResolver.swift
└── BudgetManager.swift

Domain/Models/
├── Budget.swift
└── LedgerMeta.swift
```

---

## 구현 우선순위

1. **Task 1**: 통계 차트 (Swift Charts) — 가장 시각적 임팩트
2. **Task 2**: 예산 관리 — 통계 탭과 연동
3. **Task 6**: 가계부 메타데이터 — UI 개선 기반
4. **Task 7**: 가계부 순서 변경 — 간단
5. **Task 4**: AI 파싱 서비스 — 음성/SMS의 기반
6. **Task 3**: 음성 입력 — AI 서비스 필요
7. **Task 5**: SMS 파싱 — AI 서비스 필요
8. **Task 8**: 거래 추가 화면 통합

---

## 하지 말 것

- Phase 3 기능 (Siri, 위젯, 다크모드, 검색) 금지
- SPM 외부 패키지 추가 금지 (Swift Charts, Speech는 내장)
- UIKit 직접 사용 금지
- Firebase/서버 백엔드 금지
- AI API 키를 코드에 하드코딩 금지 (UserDefaults 설정에서 입력)

---

## 완료 기준

1. 통계 탭: 월간 바 차트 + 카테고리 파이 차트 표시
2. 예산: 설정에서 월 예산 입력 → 통계 탭에서 진행률 표시
3. 가계부: 아이콘/색상 설정 → UI 전체에 반영
4. 가계부 순서 변경 동작
5. AI 설정: 엔드포인트/키/모델 저장 + 연결 테스트
6. 음성 입력: 마이크 → 텍스트 변환 → AI 파싱 → 폼 자동 채움
7. SMS 입력: 텍스트 붙여넣기 → AI 파싱 → 폼 자동 채움
8. 빌드 성공, 워닝 0건
