# Jidal CE — 위젯 & 마무리

이 문서는 두 파트로 나뉩니다:
- **파트 A**: 직접 Xcode에서 수행 (위젯 타겟 생성)
- **파트 B**: Codex 프롬프트 (위젯 코드 + 다크모드 점검)

---

# 파트 A: Xcode에서 위젯 타겟 생성 (직접 수행)

## 1. 위젯 Extension 타겟 추가

```
Xcode → File → New → Target
  → iOS → Widget Extension

설정:
  Product Name:           JidalCEWidget
  Team:                   (메인 앱과 동일)
  Include Configuration App Intent:  체크 해제
  Include Live Activity:  체크 해제
```

## 2. App Group 설정

메인 앱과 위젯이 데이터를 공유하려면 App Group 필요.

### 메인 앱 타겟:
```
JidalCE → Signing & Capabilities → + Capability → App Groups
  → + 추가: group.com.swking.JidalCE
```

### 위젯 타겟:
```
JidalCEWidget → Signing & Capabilities → + Capability → App Groups
  → 같은 그룹 선택: group.com.swking.JidalCE
```

## 3. 공유 파일 Target Membership 설정

아래 파일들을 위젯 타겟에도 포함시켜야 한다.
각 파일 선택 → File Inspector (우측 패널) → Target Membership에서 **JidalCEWidgetExtension** 체크:

```
Domain/Models/
  ├── Transaction.swift       ☑ JidalCE  ☑ JidalCEWidgetExtension
  ├── MonthlySnapshot.swift   ☑ JidalCE  ☑ JidalCEWidgetExtension
  └── Ledger.swift            ☑ JidalCE  ☑ JidalCEWidgetExtension

Services/
  └── NoteSerializer.swift    ☑ JidalCE  ☑ JidalCEWidgetExtension

Data/
  └── CalendarStore.swift     ☑ JidalCE  ☑ JidalCEWidgetExtension
```

## 4. 위젯 Deployment Target

```
JidalCEWidgetExtension → General → Minimum Deployments: iOS 26.0
```

## 5. 빌드 확인

```
Cmd + B → 메인 앱 + 위젯 둘 다 빌드 성공 확인
```

## 6. 확인 체크리스트

- [ ] JidalCEWidget 타겟 생성됨
- [ ] App Group `group.com.swking.JidalCE` 양쪽 타겟에 설정
- [ ] 공유 파일 Target Membership 설정
- [ ] 위젯 타겟 deployment target iOS 26.0
- [ ] 빌드 성공

---

# 파트 B: Codex 프롬프트 — 위젯 코드 + 다크모드

아래를 Codex에 넣으세요.

---

## Codex Task: Jidal CE — 위젯 구현 + 다크모드 마무리

### 현재 상태

Phase 3까지 거의 완료. 위젯 타겟(JidalCEWidgetExtension)이 Xcode에서 생성되었고, App Group과 공유 파일 Target Membership이 설정된 상태다. 위젯 타겟 폴더에 Xcode가 자동 생성한 기본 위젯 코드가 있다. 이것을 가계부 위젯으로 교체하라.

### App Group 식별자

```
group.com.swking.JidalCE
```

메인 앱과 위젯이 이 그룹으로 UserDefaults를 공유한다.

---

### Task 1: 메인 앱에서 공유 데이터 저장

메인 앱이 거래를 추가/수정/삭제할 때, 위젯용 공유 데이터를 갱신한다.

```swift
import WidgetKit

let sharedDefaults = UserDefaults(suiteName: "group.com.swking.JidalCE")

// 거래 변경 시 호출
func updateWidgetData() {
    // 현재 선택된 그룹 캘린더 ID
    sharedDefaults?.set(selectedGroupCalendarId, forKey: "widgetCalendarId")
    
    // 현재 선택된 가계부 이름
    sharedDefaults?.set(selectedLedgerName, forKey: "widgetLedgerName")
    
    // 위젯 리로드 요청
    WidgetCenter.shared.reloadAllTimelines()
}
```

`TransactionRepository`의 add/update/delete 메서드 끝에 `updateWidgetData()` 호출 추가.
`AppState`에서 그룹/가계부 변경 시에도 호출.

---

### Task 2: 위젯 Provider

JidalCEWidget 폴더에 있는 자동 생성 코드를 아래 구조로 교체.

```swift
import WidgetKit
import SwiftUI
import EventKit

struct JidalCEEntry: TimelineEntry {
    let date: Date
    let ledgerName: String
    let ledgerIcon: String
    let todayExpense: Int
    let todayIncome: Int
    let monthExpense: Int
    let monthIncome: Int
    let balance: Int
    let topCategories: [(String, Int)]  // 카테고리명, 금액
}

struct JidalCEWidgetProvider: TimelineProvider {
    let store = EKEventStore()
    let sharedDefaults = UserDefaults(suiteName: "group.com.swking.JidalCE")
    
    func placeholder(in context: Context) -> JidalCEEntry {
        JidalCEEntry(
            date: Date(),
            ledgerName: "생활비",
            ledgerIcon: "💰",
            todayExpense: 0, todayIncome: 0,
            monthExpense: 0, monthIncome: 0,
            balance: 0, topCategories: []
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (JidalCEEntry) -> Void) {
        completion(buildEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<JidalCEEntry>) -> Void) {
        let entry = buildEntry()
        // 30분마다 갱신
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func buildEntry() -> JidalCEEntry {
        let calId = sharedDefaults?.string(forKey: "widgetCalendarId") ?? ""
        let ledgerName = sharedDefaults?.string(forKey: "widgetLedgerName") ?? "생활비"
        
        guard let calendar = store.calendar(withIdentifier: calId) else {
            return placeholder(in: .init())  // 캘린더 없으면 빈 데이터
        }
        
        let today = Date()
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: today)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!
        
        // 오늘 거래
        let todayEvents = store.events(matching: store.predicateForEvents(
            withStart: dayStart, end: dayEnd, calendars: [calendar]
        )).filter { $0.title == ledgerName && $0.url?.scheme == "jidalce" }
        
        let todayTransactions = todayEvents.flatMap { NoteSerializer.parse($0.notes ?? "") }
        let todayExp = todayTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount }
        let todayInc = todayTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        
        // 월간 거래
        let monthEvents = store.events(matching: store.predicateForEvents(
            withStart: monthStart, end: monthEnd, calendars: [calendar]
        )).filter { $0.title == ledgerName && $0.url?.scheme == "jidalce" }
        
        let monthTransactions = monthEvents.flatMap { NoteSerializer.parse($0.notes ?? "") }
        let monthExp = monthTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount }
        let monthInc = monthTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        
        // 카테고리 Top 3 (지출만)
        let categoryTotals = Dictionary(grouping: monthTransactions.filter { $0.amount < 0 }) { $0.category }
            .mapValues { $0.reduce(0) { $0 + abs($1.amount) } }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { ($0.key, $0.value) }
        
        // 잔액 (간이 계산: 월간 기준)
        // 위젯에서 스냅샷까지 조회하면 무거우므로, sharedDefaults에 캐시된 잔액 사용
        let cachedBalance = sharedDefaults?.integer(forKey: "widgetBalance") ?? 0
        
        return JidalCEEntry(
            date: today,
            ledgerName: ledgerName,
            ledgerIcon: sharedDefaults?.string(forKey: "widgetLedgerIcon") ?? "💰",
            todayExpense: todayExp,
            todayIncome: todayInc,
            monthExpense: monthExp,
            monthIncome: monthInc,
            balance: cachedBalance,
            topCategories: categoryTotals
        )
    }
}
```

---

### Task 3: 위젯 뷰

#### Small 위젯 (오늘 지출 + 잔액)

```swift
struct SmallWidgetView: View {
    let entry: JidalCEEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.ledgerIcon)
                Text(entry.ledgerName)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Spacer()
            
            Text("오늘 지출")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatAmount(entry.todayExpense))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.red)
            
            Spacer()
            
            Text("잔액")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(formatAmount(entry.balance))
                .font(.caption)
                .fontWeight(.medium)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    func formatAmount(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let str = formatter.string(from: NSNumber(value: abs(amount))) ?? "0"
        return (amount < 0 ? "-" : "") + str + "원"
    }
}
```

#### Medium 위젯 (월간 요약)

```swift
struct MediumWidgetView: View {
    let entry: JidalCEEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // 좌측: 금액 요약
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.ledgerIcon)
                    Text(entry.ledgerName)
                        .font(.caption)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(monthString())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                LabeledAmount(label: "지출", amount: entry.monthExpense, color: .red)
                LabeledAmount(label: "수입", amount: entry.monthIncome, color: .blue)
                LabeledAmount(label: "잔액", amount: entry.balance, color: .primary)
            }
            
            // 우측: 카테고리 Top 3
            if !entry.topCategories.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("카테고리")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(entry.topCategories, id: \.0) { cat, amount in
                        HStack {
                            Text(cat).font(.caption2)
                            Spacer()
                            Text(formatAmount(-amount))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
    
    func monthString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월"
        return formatter.string(from: entry.date)
    }
}

struct LabeledAmount: View {
    let label: String
    let amount: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text(formatAmount(amount))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}
```

---

### Task 4: 위젯 등록

JidalCEWidget 폴더의 메인 Widget 파일:

```swift
import WidgetKit
import SwiftUI

@main
struct JidalCEWidgetBundle: WidgetBundle {
    var body: some Widget {
        JidalCESmallWidget()
        JidalCEMediumWidget()
    }
}

struct JidalCESmallWidget: Widget {
    let kind = "JidalCESmallWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JidalCEWidgetProvider()) { entry in
            SmallWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘 지출")
        .description("오늘 지출 금액과 잔액을 표시합니다")
        .supportedFamilies([.systemSmall])
    }
}

struct JidalCEMediumWidget: Widget {
    let kind = "JidalCEMediumWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JidalCEWidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
        }
        .configurationDisplayName("월간 요약")
        .description("이번 달 지출/수입 요약과 카테고리 현황을 표시합니다")
        .supportedFamilies([.systemMedium])
    }
}
```

---

### Task 5: 메인 앱에서 잔액 캐시 갱신

위젯이 스냅샷까지 직접 조회하면 무거우므로, 메인 앱에서 잔액을 계산하고 공유 UserDefaults에 캐시:

```swift
// BalanceCalculator 또는 AppState에서 잔액 갱신 시:
func cacheBalanceForWidget(balance: Int, ledgerIcon: String) {
    let shared = UserDefaults(suiteName: "group.com.swking.JidalCE")
    shared?.set(balance, forKey: "widgetBalance")
    shared?.set(ledgerIcon, forKey: "widgetLedgerIcon")
    WidgetCenter.shared.reloadAllTimelines()
}
```

호출 시점:
- 앱 실행 시 잔액 계산 후
- 거래 추가/수정/삭제 후
- 가계부 전환 시
- 장부정리 완료 후

---

### Task 6: 다크모드 전체 점검

모든 View 파일에서 하드코딩된 색상을 시맨틱 색상으로 교체:

```swift
// 교체 대상
Color.white     → Color(.systemBackground)
Color.black     → Color(.label)
Color(white: x) → Color(.systemBackground).opacity(x) 또는 적절한 시맨틱
Color.gray      → Color(.secondaryLabel)
```

확인할 화면:
- 달력 탭: 그리드 배경, 날짜 숫자, 선택 하이라이트
- 거래 목록: 셀 배경, 금액 텍스트
- 거래 추가 폼: 입력 필드 배경
- 통계 차트: 바/파이 차트 색상, 범례 텍스트
- 설정: 섹션 배경, 텍스트
- 위젯: containerBackground 적용 확인

Xcode Preview에서 확인:
```swift
#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
```

---

### 구현 순서

1. Task 6: 다크모드 점검 (빠르게)
2. Task 5: 잔액 캐시 (메인 앱 수정)
3. Task 1: 공유 데이터 저장 (메인 앱 수정)
4. Task 2: 위젯 Provider
5. Task 3: 위젯 뷰 (Small + Medium)
6. Task 4: 위젯 등록

### 하지 말 것

- 위젯에서 네트워크 호출 금지
- 위젯에서 스냅샷 직접 조회 금지 (캐시 사용)
- 위젯 타겟 생성/pbxproj 수정 금지 (이미 완료됨)
- SPM 패키지 추가 금지

### 완료 기준

1. Small 위젯: 오늘 지출 + 잔액 표시
2. Medium 위젯: 월간 지출/수입/잔액 + 카테고리 Top 3
3. 거래 추가/삭제 시 위젯 자동 갱신
4. 다크모드에서 앱 전체 + 위젯 정상 표시
5. 빌드 성공, 워닝 0건 (메인 앱 + 위젯 둘 다)
