# Codex Task: Jidal CE — Phase 3: 편의 기능 및 출시 준비

## 현재 상태

Phase 1(MVP) + Phase 2(차트/음성/SMS/예산/메타) 완료. 빌드 성공, 워닝 0건. 이번 Phase 3에서는 출시 전 편의 기능과 완성도를 높인다.

---

## Task 1: iCloud 캘린더 공유 안내 가이드

앱 내에서 프로그래밍적 공유 초대는 불가하므로, 사용자가 iOS 설정에서 캘린더를 공유하도록 안내하는 가이드 화면을 제공한다.

### 가이드 화면 (SharingGuideView)

```
┌─────────────────────────────┐
│  캘린더 공유하기               │
├─────────────────────────────┤
│                             │
│  가족이나 파트너와 가계부를    │
│  함께 사용하려면 캘린더를      │
│  공유하세요.                  │
│                             │
│  ── 방법 ──                  │
│                             │
│  1️⃣ iPhone 설정 앱 열기      │
│                             │
│  2️⃣ 캘린더 탭               │
│                             │
│  3️⃣ 계정 → iCloud →         │
│     "우리집" 캘린더 선택      │
│                             │
│  4️⃣ 사람 추가 →              │
│     상대방 Apple ID 입력     │
│                             │
│  5️⃣ 상대방이 초대 수락하면    │
│     자동으로 가계부 공유!     │
│                             │
│  [ 설정 앱 열기 ]             │
│                             │
│  💡 상대방도 이 앱을 설치하면  │
│     같은 캘린더를 선택하여    │
│     함께 사용할 수 있습니다.   │
│                             │
└─────────────────────────────┘
```

### 설정 앱 열기 버튼

```swift
Button("설정 앱 열기") {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}
```

### 진입점
- 설정 탭 → 그룹 관리 → "캘린더 공유" 버튼
- 온보딩 완료 후 공유 안내 팝업 (1회)

---

## Task 2: Siri / App Shortcuts

### AppShortcuts 정의

```swift
import AppIntents

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "가계부 지출 기록"
    static var description: IntentDescription = "음성으로 지출을 기록합니다"
    
    @Parameter(title: "내용")
    var spokenText: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("'\(\.$spokenText)' 지출 기록")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 1. AIService로 파싱
        let aiService = AIService()
        let parsed = try await aiService.parseVoiceInput(spokenText)
        
        // 2. 날짜 해석
        let date = ParsedTransactionDateResolver.resolve(parsed.date)
        
        // 3. 거래 저장
        let repo = TransactionRepository(store: CalendarStore.shared)
        let transaction = Transaction(
            id: UUID().uuidString.prefix(4).lowercased(),
            amount: -(parsed.amount ?? 0),
            category: parsed.category ?? "기타",
            memo: parsed.memo ?? spokenText,
            time: DateFormatter.timeOnly.string(from: Date()),
            by: UserDefaults.standard.string(forKey: "nickname") ?? UIDevice.current.name,
            date: date,
            ledgerName: UserDefaults.standard.string(forKey: "lastLedger") ?? "생활비"
        )
        try repo.addTransaction(transaction, calendar: /* 현재 그룹 캘린더 */)
        
        return .result(dialog: "\(parsed.memo ?? "거래") \(parsed.amount ?? 0)원 기록했습니다")
    }
}

struct UndoLastTransactionIntent: AppIntent {
    static var title: LocalizedStringResource = "마지막 거래 취소"
    static var description: IntentDescription = "가장 최근에 기록한 거래를 삭제합니다"
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        // 마지막 거래 찾기 → 삭제 → 히스토리 기록
        return .result(dialog: "마지막 거래를 삭제했습니다")
    }
}
```

### AppShortcuts Provider

```swift
struct JidalCEShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "지갑의달인에서 \(\.$spokenText) 기록",
                "지갑의달인 \(\.$spokenText) 지출",
                "가계부에 \(\.$spokenText) 기록"
            ],
            shortTitle: "지출 기록",
            systemImageName: "won.circle"
        )
        AppShortcut(
            intent: UndoLastTransactionIntent(),
            phrases: [
                "지갑의달인 마지막 거래 취소",
                "가계부 마지막 기록 삭제"
            ],
            shortTitle: "마지막 거래 취소",
            systemImageName: "arrow.uturn.backward"
        )
    }
}
```

### JidalCEApp에 등록

```swift
@main
struct JidalCEApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

AppShortcutsProvider는 자동 검색되므로 별도 등록 불필요. 단, AI 설정이 되어 있지 않으면 Siri 파싱 실패 → 에러 다이얼로그 반환.

---

## Task 3: 위젯

### WidgetKit 타겟 추가

```
Xcode → File → New → Target → Widget Extension
  이름: JidalCEWidget
  ☑ Include Configuration App Intent 체크 해제
```

### 위젯 종류

#### 오늘 지출 위젯 (Small)

```
┌──────────────┐
│  💰 생활비    │
│              │
│  오늘 지출    │
│  -45,500원   │
│              │
│  잔액         │
│  2,500,000원  │
└──────────────┘
```

#### 월간 요약 위젯 (Medium)

```
┌──────────────────────────────┐
│  💰 생활비        4월         │
│                              │
│  지출 350,000원  수입 5,000,000원 │
│  잔액 2,500,000원             │
│                              │
│  식비 34% · 교통 24% · 생활 27% │
└──────────────────────────────┘
```

### 위젯 데이터 공유

위젯은 별도 프로세스이므로 EventKit 접근을 위해 App Group 설정 필요:

```
1. 메인 앱 + 위젯 Target 둘 다:
   Signing & Capabilities → + App Groups
   group.com.swking.JidalCE

2. CalendarStore에서 App Group UserDefaults 사용:
   let sharedDefaults = UserDefaults(suiteName: "group.com.swking.JidalCE")
```

위젯에서 직접 EventKit 조회:

```swift
struct JidalCEWidgetProvider: TimelineProvider {
    let store = EKEventStore()
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<JidalCEEntry>) -> Void) {
        // EventKit으로 오늘 거래 조회
        // 캘린더 identifier는 App Group UserDefaults에서 가져옴
        let calId = sharedDefaults.string(forKey: "selectedGroupCalendarId")
        guard let calendar = store.calendar(withIdentifier: calId ?? "") else {
            // 기본 엔트리 반환
            return
        }
        
        // 오늘 거래 fetch + 파싱
        let today = Date()
        let predicate = store.predicateForEvents(
            withStart: Calendar.current.startOfDay(for: today),
            end: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: today))!,
            calendars: [calendar]
        )
        let events = store.events(matching: predicate)
        // NoteSerializer로 파싱...
        
        let entry = JidalCEEntry(date: today, todayExpense: totalExpense, balance: balance)
        let timeline = Timeline(entries: [entry], policy: .after(
            Calendar.current.date(byAdding: .minute, value: 30, to: today)!
        ))
        completion(timeline)
    }
}
```

### 위젯에서 NoteSerializer 공유

NoteSerializer.swift를 위젯 타겟에도 추가 (Target Membership 체크).
또는 공유 프레임워크로 분리.

간단하게 가려면: 파일의 Target Membership에 JidalCEWidget도 체크.

---

## Task 4: 검색 기능

### 거래 메모 검색

```
목록 탭 상단에 검색바:

┌─────────────────────────────┐
│  🔍 거래 검색                │
├─────────────────────────────┤
│                             │
│  검색어: "김밥"              │
│                             │
│  ── 검색 결과 (5건) ──       │
│                             │
│  4/01  점심 김밥천국  -8,500원│
│  3/25  김밥천국      -9,000원│
│  3/12  김밥나라      -7,500원│
│  ...                        │
│                             │
└─────────────────────────────┘
```

### 구현

```swift
func searchTransactions(query: String, calendar: EKCalendar, 
                        ledgerName: String, months: Int = 6) -> [Transaction] {
    // 최근 N개월 이벤트 fetch
    let events = fetchEvents(from: nMonthsAgo, to: Date(), calendar: calendar)
    
    // 각 이벤트 notes 파싱 → 메모에 query 포함된 거래 필터
    return events
        .filter { $0.title == ledgerName && isJidalEvent($0) }
        .flatMap { NoteSerializer.parse($0.notes ?? "") }
        .filter { $0.memo.localizedCaseInsensitiveContains(query) }
        .sorted { $0.date > $1.date }
}
```

검색 범위: 최근 6개월 (성능). 더 필요하면 "더 검색" 버튼으로 범위 확장.

### UI

SwiftUI `.searchable(text:)` 사용:

```swift
.searchable(text: $searchQuery, prompt: "거래 검색")
```

---

## Task 5: 다크모드 대응

### 확인 사항

SwiftUI 기본 컴포넌트는 자동 대응되므로, 커스텀 색상만 점검:

```swift
// 하드코딩된 색상이 있는지 확인하고 시맨틱 색상으로 교체
Color.white → Color(.systemBackground)
Color.black → Color(.label)
Color.gray  → Color(.secondaryLabel)

// 차트 색상은 다크모드에서도 잘 보이는지 확인
// 파이 차트 레이블이 배경과 겹치지 않는지 확인
```

### 점검 파일 목록

- CalendarTabView.swift — 달력 그리드 배경, 날짜 텍스트
- DayDetailView.swift — 거래 목록 셀
- MonthlyFlowChart.swift — 바 차트 색상
- CategoryPieChart.swift — 도넛 차트 + 범례 텍스트
- AddTransactionView.swift — 입력 폼 배경
- 모든 View에서 `Color(hex:)` 같은 커스텀 색상 사용 부분

### 테스트

Xcode Preview에서 `.preferredColorScheme(.dark)` 적용하여 전체 화면 확인.

---

## Task 6: 프롬프트 설정 (편집 가능)

기존 Jidal에 있었던 프롬프트 커스터마이징 기능. AI 파싱 프롬프트를 사용자가 직접 수정할 수 있게 한다.

### 프롬프트 종류

```swift
enum PromptType: String, CaseIterable {
    case voice = "음성 입력 파싱"
    case sms = "SMS 파싱"
}
```

### 기본 프롬프트

AIService에 내장된 기본 프롬프트. 사용자가 수정하지 않으면 이 값 사용.

### 설정 화면

```
설정 → AI 설정 → 프롬프트 편집

  음성 입력 파싱 ▶    ← 탭하면 편집 팝업
  SMS 파싱 ▶          ← 탭하면 편집 팝업
  
  [ 전체 초기화 ]      ← 모든 프롬프트를 기본값으로
```

편집 팝업:

```
┌─────────────────────────────┐
│  음성 입력 파싱 프롬프트       │
├─────────────────────────────┤
│                             │
│  TextEditor (여러 줄)        │
│  ┌───────────────────────┐  │
│  │ 다음 한국어 텍스트에서  │  │
│  │ 가계부 거래 정보를...   │  │
│  │ ...                   │  │
│  └───────────────────────┘  │
│                             │
│  [ 초기화 ]    [ 저장 ]      │
│                             │
└─────────────────────────────┘
```

### 저장

```swift
class PromptSettingsManager {
    func prompt(for type: PromptType) -> String {
        // UserDefaults에 저장된 커스텀 프롬프트 우선
        // 없으면 기본 프롬프트 반환
    }
    func save(prompt: String, for type: PromptType)
    func reset(type: PromptType)
    func resetAll()
}
```

AIService에서 파싱 호출 시 `PromptSettingsManager.prompt(for:)` 사용.

---

## 새 파일 목록

```
Features/
├── Sharing/
│   └── SharingGuideView.swift
├── Search/
│   └── TransactionSearchView.swift
├── Settings/
│   └── PromptSettingsView.swift

Intents/
├── AddExpenseIntent.swift
├── UndoLastTransactionIntent.swift
└── JidalCEShortcuts.swift

JidalCEWidget/
├── JidalCEWidget.swift
├── JidalCEWidgetProvider.swift
├── JidalCEEntry.swift
├── SmallWidgetView.swift
└── MediumWidgetView.swift

Services/
└── PromptSettingsManager.swift
```

---

## 구현 우선순위

1. **Task 5**: 다크모드 — 전체 UI 점검 (빠르게 끝남)
2. **Task 4**: 검색 — `.searchable` 한 줄로 시작
3. **Task 1**: 공유 가이드 — 단순 안내 화면
4. **Task 6**: 프롬프트 설정 — AI 기능 보완
5. **Task 2**: Siri / App Shortcuts — AppIntents
6. **Task 3**: 위젯 — 별도 타겟, App Group 필요

---

## 하지 말 것

- UIKit 직접 사용 금지
- SPM 외부 패키지 금지
- 서버 백엔드 금지
- AI 키 하드코딩 금지
- 위젯에서 네트워크 호출 금지 (EventKit 로컬 데이터만)

---

## 완료 기준

1. 다크모드에서 모든 화면 정상 표시
2. 거래 검색: 메모 키워드로 검색 → 결과 목록 표시
3. 공유 가이드: 설정에서 접근 가능, 설정 앱 열기 버튼 동작
4. 프롬프트 편집: 음성/SMS 프롬프트 수정 → AI 파싱에 반영
5. Siri: "지갑의달인에서 점심 만원 기록" → 거래 추가됨
6. 위젯: 소형(오늘 지출+잔액) + 중형(월간 요약) 표시
7. 빌드 성공, 워닝 0건
