# Codex Task: 가계부 아이콘을 이모지에서 SF Symbols로 전환

## 목표

현재 가계부 아이콘이 이모지 문자열(💰, 🏠, ✈️ 등)로 되어 있다. 이것을 Apple SF Symbols로 전환하여 단색 아이콘 세트로 통일한다.

**⚠️ 핵심 주의사항: SF Symbol 이름은 `Image(systemName:)`으로만 렌더링해야 한다. 절대 `Text()`로 출력하지 마라. `Text()`에 넣으면 아이콘이 아닌 문자열이 화면에 그대로 출력된다.**

---

## Step 1: 아이콘 프리셋 교체

현재 이모지 프리셋을 SF Symbol 이름으로 교체한다.

### Before (현재)
```swift
let ledgerIcons = ["💰", "🏠", "✈️", "🚗", "🎓", "💊", "🛒", "👶", "🐶", "🎮", "📱", "💳"]
```

### After
```swift
let ledgerIcons = [
    "wonsign.circle.fill",          // 생활비/기본
    "house.fill",                    // 집
    "airplane",                      // 여행
    "car.fill",                      // 교통
    "graduationcap.fill",           // 교육
    "cross.case.fill",              // 의료
    "cart.fill",                     // 장보기
    "figure.and.child.holdinghands", // 아이
    "pawprint.fill",                // 반려동물
    "gamecontroller.fill",          // 게임
    "iphone",                       // 통신
    "creditcard.fill",              // 카드
    "banknote.fill",                // 저축
    "gift.fill",                    // 선물
    "cup.and.saucer.fill",         // 카페
    "fork.knife",                   // 음식
]
```

이 배열이 정의된 파일(LedgerEditView.swift 또는 별도 상수 파일)을 찾아서 교체.

### 기본 아이콘 변경

가계부 생성 시 기본 아이콘도 교체:

```swift
// Before
var icon: String = "💰"

// After
var icon: String = "wonsign.circle.fill"
```

해당되는 모든 곳: Ledger 모델 기본값, LedgerMeta 기본값, LedgerRepository 기본값 등.

---

## Step 2: 모든 아이콘 렌더링을 Image(systemName:)으로 변경

프로젝트 전체에서 아이콘을 화면에 표시하는 모든 곳을 찾아서 수정한다.

### 패턴 A: Text(icon) → Image(systemName: icon)

```swift
// ❌ Before (이모지에서는 동작했지만 SF Symbol에서는 문자열 출력됨)
Text(ledger.icon)

// ✅ After
Image(systemName: ledger.icon)
    .foregroundStyle(.secondary)
```

### 패턴 B: 문자열 보간 → HStack 분리

```swift
// ❌ Before
Text("\(ledger.icon) \(ledger.name)")

// ✅ After
HStack(spacing: 4) {
    Image(systemName: ledger.icon)
    Text(ledger.name)
}
```

### 패턴 C: Label 활용 (텍스트와 아이콘이 나란한 경우)

```swift
// ✅ 가장 깔끔한 방법
Label(ledger.name, systemImage: ledger.icon)
```

### 패턴 D: 아이콘 선택 UI

```swift
// ❌ Before
ForEach(ledgerIcons, id: \.self) { icon in
    Button(icon) { selectedIcon = icon }
}

// ✅ After
LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
    ForEach(ledgerIcons, id: \.self) { icon in
        Button {
            selectedIcon = icon
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
```

---

## Step 3: 수정 대상 파일 (전부 확인)

아래 파일들에서 아이콘 관련 코드를 빠짐없이 확인하라:

**UI 파일 — 아이콘 표시:**
- CalendarTabView.swift — 상단 가계부 선택 영역
- DayDetailView.swift — 거래 목록 셀
- TransactionListView.swift — 거래 목록 셀
- AddTransactionView.swift — 가계부 선택 드롭다운
- StatisticsView.swift — 가계부 표시
- SettingsRootView.swift — 메뉴 항목
- LedgerManagementView.swift — 가계부 목록
- LedgerEditView.swift — 아이콘 선택 UI + 미리보기
- GroupManagementView.swift — 그룹 내 가계부 표시
- HistoryView.swift — 히스토리 항목 (있다면)

**위젯 파일:**
- SmallWidgetView.swift — 가계부 아이콘
- MediumWidgetView.swift — 가계부 아이콘

**데이터 파일 — 기본값:**
- Ledger.swift 또는 LedgerMeta.swift — icon 기본값
- LedgerRepository.swift — 가계부 생성 시 기본 아이콘
- GroupRepository.swift — (있다면)
- AppState.swift — (있다면)

**__meta_ 이벤트 메모 포맷:**
메타 이벤트 메모에 아이콘을 저장하는 부분. SF Symbol 이름 문자열을 그대로 저장하면 된다 (변경 불필요). 읽어올 때 Image(systemName:)으로 렌더링하는 것만 확인.

```
아이콘: wonsign.circle.fill     ← 저장은 문자열 그대로 OK
```

---

## Step 4: 위젯 공유 데이터

위젯에 캐시하는 아이콘 데이터도 SF Symbol 이름으로:

```swift
// 메인 앱에서 캐시 저장
sharedDefaults?.set("wonsign.circle.fill", forKey: "widgetLedgerIcon")

// 위젯에서 렌더링
Image(systemName: entry.ledgerIcon)  // ✅ Text 아님
```

---

## Step 5: 기존 데이터 마이그레이션

이미 캘린더에 이모지로 저장된 __meta_ 이벤트가 있을 수 있다. 앱 실행 시 마이그레이션:

```swift
func migrateIconIfNeeded(icon: String) -> String {
    let emojiToSFSymbol: [String: String] = [
        "💰": "wonsign.circle.fill",
        "🏠": "house.fill",
        "✈️": "airplane",
        "🚗": "car.fill",
        "🎓": "graduationcap.fill",
        "💊": "cross.case.fill",
        "🛒": "cart.fill",
        "👶": "figure.and.child.holdinghands",
        "🐶": "pawprint.fill",
        "🎮": "gamecontroller.fill",
        "📱": "iphone",
        "💳": "creditcard.fill",
    ]
    return emojiToSFSymbol[icon] ?? icon
}
```

LedgerRepository에서 메타를 읽어올 때 이 함수를 통과시킨다. 마이그레이션된 값은 다시 저장.

---

## 절대 하지 말 것

- **`Text(icon)`, `Text(ledger.icon)`, `Text(entry.ledgerIcon)` 사용 금지** — SF Symbol 이름이 문자열로 출력됨
- **`"\(icon)"` 문자열 보간에 아이콘 넣기 금지** — 같은 문제
- 이모지로 되돌리지 마라
- 아이콘 프로퍼티 타입(String)은 변경하지 마라

## 반드시 할 것

- 아이콘을 화면에 표시할 때는 **예외 없이** `Image(systemName: icon)` 또는 `Label(text, systemImage: icon)` 사용
- 프로젝트 전체에서 빠짐없이 확인 — grep으로 `Text(.*icon` 패턴 검색하여 누락 없는지 확인

---

## 완료 기준

1. 앱 전체에서 이모지가 보이는 곳이 0개 (아이콘 관련)
2. 모든 가계부 아이콘이 SF Symbol 단색 아이콘으로 표시됨
3. 아이콘 선택 화면에서 SF Symbol 그리드로 선택 가능
4. 위젯에서도 SF Symbol 아이콘 정상 표시
5. 기존 이모지 데이터 마이그레이션 동작
6. `Text(.*icon` 패턴 grep 결과 0건
7. 빌드 성공, 워닝 0건
