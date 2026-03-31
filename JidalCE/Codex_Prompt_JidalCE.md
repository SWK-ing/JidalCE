# Codex Task: Jidal CE (지갑의달인 Calendar Edition) — Phase 1 MVP 개발

## 역할

너는 iOS SwiftUI 앱 개발 전문가다. 아래 프로젝트 사양서를 정확히 따라 Phase 1 MVP를 구현하라.

## 프로젝트 요약

iOS 네이티브 캘린더(EventKit)를 데이터베이스로 사용하는 공유 가계부 앱이다. Firebase 없음, 서버 없음, 로그인 없음. 캘린더 이벤트의 메모 필드에 구조화된 텍스트로 거래 데이터를 저장하고, iCloud 캘린더 공유로 멀티유저를 지원한다.

## 기술 스택

- **언어**: Swift 6+
- **UI**: SwiftUI
- **최소 지원**: iOS 17.0
- **프레임워크**: EventKit (캘린더 읽기/쓰기)
- **외부 의존성**: 없음 (SPM 패키지 없음)
- **아키텍처**: MVVM + Repository 패턴

---

## 핵심 아키텍처: 캘린더 = 데이터베이스

### 개념 매핑

| 앱 개념 | 캘린더 매핑 | 식별 방법 |
|---|---|---|
| 그룹 (Household) | EKCalendar | 캘린더 이름 |
| 가계부 (Ledger) | EKEvent 제목 | 이벤트 title |
| 일일 거래 묶음 | EKEvent 1개 | 날짜 + 제목 조합 |
| 개별 거래 | notes 내 파싱 라인 | 거래 ID (#xxxx) |
| 월간 스냅샷 | 전용 EKEvent | 제목 `__snapshot_{가계부명}__` |
| 월간 변경 이력 | 전용 EKEvent | 제목 `__history_{가계부명}_{YYYY-MM}__` |
| 가계부 메타 | 전용 EKEvent | 제목 `__meta_{가계부명}__` |

### 이벤트 공통 규칙

- 모든 이벤트는 `isAllDay = true`
- 모든 이벤트의 `url`에 앱 스킴 설정: `jidalce://` (기존 캘린더 사용 시 가계부 이벤트 식별용)
- 시스템 이벤트 판별: title이 `__snapshot_`, `__history_`, `__meta_`로 시작하면 시스템 이벤트

---

## 메모 포맷 사양 (가장 중요 — 정확히 지켜야 함)

### 거래 이벤트 메모 (NoteSerializer)

사람이 읽었을 때 영수증처럼 보이면서, 앱에서 파싱 가능한 구조:

```
점심 김밥천국
  -8,500원 | 식비 | 12:30 | 마스터
주유
  -45,000원 | 교통 | 18:20 | 마스터
저녁 치킨
  -15,000원 | 식비 | 20:00 | 배우자
──────────
지출 68,500원 (3건)
──────────
#a1f3 #b2e7 #c9d2
```

**파싱 규칙:**
1. 들여쓰기 없는 줄 = 거래 메모(설명)
2. 들여쓰기(`  `, 공백 2칸) 시작 줄 = 데이터 라인
3. 데이터 라인 포맷: `  {부호}{금액}원 | {카테고리} | {시간} | {작성자}`
   - `+` = 수입, `-` = 지출
   - 금액에 천 단위 콤마 포함
   - 시간은 `HH:mm` 24시간제
4. `──`로 시작하는 줄 = 구분선
5. 첫 번째 구분선 ~ 두 번째 구분선 = 요약 텍스트 (표시용, 파싱 무시)
6. 마지막 줄 `#xxxx #yyyy ...` = 거래 ID 목록 (메모-데이터 쌍과 순서 1:1 매칭)

**거래 ID**: 4자리 hex 랜덤, 같은 이벤트 내 중복 불가

### 스냅샷 이벤트 메모

```
── 2월 마감 ──
이월: 1,250,000원
수입: 5,000,000원
지출: 3,750,000원
잔액: 2,500,000원
──────────
#snapshot:2026-02
```

- 이벤트 제목: `__snapshot_{가계부명}__`
- 이벤트 날짜: 마감 대상 월의 **다음 달 1일** (2월 마감 → 3월 1일)
- `잔액:` 뒤 금액 = 마감 잔액 (다음 달 이월액)

### 히스토리 이벤트 메모

```
4/01 12:30 추가 | 점심 김밥천국 -8,500원 | 마스터
4/01 18:20 추가 | 주유 -45,000원 | 마스터
4/02 09:15 수정 | 주유 -45,000→-43,000원 | 배우자
4/02 20:00 삭제 | 저녁 치킨 -15,000원 | 마스터
──────────
4월: 추가 2건, 수정 1건, 삭제 1건
──────────
#history:2026-04
```

- 이벤트 제목: `__history_{가계부명}_{YYYY-MM}__`
- 이벤트 날짜: 대상 월의 1일
- notes가 50KB 초과 시 suffix `-B`, `-C`로 자동 분할

### 가계부 메타 이벤트 메모

```
아이콘: 💰
색상: blue
통화: KRW
생성일: 2024-01-15
──────────
#meta:생활비
```

- 이벤트 제목: `__meta_{가계부명}__`
- 이벤트 날짜: 고정 (2000-01-01 등)

---

## 데이터 모델

```swift
struct JidalGroup: Identifiable {
    let id: String  // calendarIdentifier
    var name: String
    var color: CGColor
}

struct Ledger: Identifiable {
    var id: String { name }
    let name: String
    var icon: String
    var color: String
    var currency: String
    var sortOrder: Int
}

struct Transaction: Identifiable {
    let id: String              // 4자리 hex
    var amount: Int             // 음수=지출, 양수=수입
    var category: String
    var memo: String
    var time: String            // "HH:mm"
    var by: String              // 작성자 이름
    var date: Date              // 이벤트 날짜
    var ledgerName: String      // 소속 가계부
}

struct MonthlySnapshot {
    let yearMonth: String       // "2026-02"
    let carryOver: Int          // 이월 잔액
    let totalIncome: Int
    let totalExpense: Int
    let closingBalance: Int     // 마감 잔액
}

struct HistoryEntry: Identifiable {
    let id = UUID()
    let date: String            // "4/01"
    let time: String            // "12:30"
    let action: HistoryAction
    let memo: String
    let amount: String          // "-8,500원" 또는 "-45,000→-43,000원"
    let by: String
}

enum HistoryAction: String {
    case added = "추가"
    case modified = "수정"
    case deleted = "삭제"
}
```

---

## CRUD 흐름 (반드시 이 순서대로 구현)

### 거래 추가
```
1. 입력: 금액, 카테고리, 메모, 가계부명
2. 해당 날짜 + 해당 가계부명의 이벤트 검색 (그룹 캘린더, 당일 범위)
   → title == 가계부명 && 시스템 이벤트 아님 && url.scheme == "jidalce"
3-A. 이벤트 존재:
   → notes 파싱 → transactions 배열에 append → 요약 재계산 → ID 추가 → notes 재직렬화 → save
3-B. 이벤트 미존재:
   → 새 All-day 이벤트 생성 → notes에 1건 직렬화 → url 설정 → save
4. 히스토리 이벤트에 "추가" 라인 append
```

### 거래 수정
```
1. 이벤트 검색 → notes 파싱 → ID로 대상 찾기
2. 변경 전 금액 보존 → 필드 수정 → 재직렬화 → save
3. 히스토리에 "수정" 라인 append (이전→이후 금액)
```

### 거래 삭제
```
1. 이벤트 검색 → notes 파싱 → ID로 대상 제거
2. 남은 거래 있으면 재직렬화 → save / 없으면 이벤트 삭제
3. 히스토리에 "삭제" 라인 append
```

---

## 잔액 및 스냅샷 전략

### 규칙
- 스냅샷은 **전전월**까지만 자동 생성
- 전월 + 당월은 항상 라이브 계산
- `잔액 = 최근 스냅샷 잔액 + 전월 거래 합산 + 당월 거래 합산`

### 자동 스냅샷 생성 (앱 실행 시)
```
현재 월 = 4월 → 전전월 = 2월
2월 스냅샷 있나?
  없으면: 1월 스냅샷 잔액(없으면 0) + 2월 거래 합산 → 2월 스냅샷 생성 (3월 1일에 배치)
  있으면: 패스
```

### 장부정리 (수동 스냅샷 재생성)
```
사용자가 시작일 선택 (첫 사용일을 가이드로 제공)
종료일 = 전전월 (자동, 변경 불가)
→ 해당 범위의 스냅샷 전부 삭제
→ 시작일부터 월별 순차 재계산하여 스냅샷 재생성
→ 프로그레스 표시
```

### 첫 사용일 감지
```swift
func detectFirstRecordDate(calendar: EKCalendar) -> Date? {
    // 4년 단위로 과거 탐색 (EventKit 쿼리 최대 4년 제한)
    // 시스템 이벤트 제외하고 가장 오래된 이벤트의 startDate 반환
}
```

### EventKit 4년 쿼리 제한 대응
4년 넘는 범위 조회 시 3.5년 단위 청크로 분할하여 반복 쿼리.

---

## 캘린더 선택 방식 (온보딩)

### 새 캘린더 만들기 (권장)
```swift
let calendar = EKCalendar(for: .event, eventStore: store)
calendar.title = groupName
calendar.cgColor = selectedColor
calendar.source = store.sources.first { $0.sourceType == .calDAV } // iCloud
try store.saveCalendar(calendar, commit: true)
```

### 기존 캘린더 선택 (옵션)
- `store.calendars(for: .event)` 목록 표시
- 선택 시 경고: "기존 일정과 가계부 기록이 함께 표시됩니다"
- 기존 캘린더의 비-가계부 이벤트는 `url.scheme != "jidalce"`로 필터링

---

## 히스토리 UI 표시

- 당월 + 전월 히스토리 이벤트를 합침
- 분할 이벤트(-B, -C)도 함께 로드
- 시간순 병합 후 최신순 정렬
- **상위 30건만 표시**
- 하단 안내: "이전 이력은 캘린더 앱에서 히스토리 이벤트를 확인하세요"

---

## 앱 라우팅

```
calendarPermission → groupSetup → main
```

| 단계 | 조건 | 화면 |
|---|---|---|
| calendarPermission | 캘린더 접근 권한 없음 | 권한 요청 안내 |
| groupSetup | 그룹 캘린더 없음 | 새 캘린더 만들기 또는 기존 선택 |
| main | 그룹 존재 | 4탭 메인 화면 |

---

## 화면 구성

### 메인 탭 구조
```
┌─────────────────────────────┐
│  [그룹선택 ▼]  [가계부선택 ▼]│
├─────────────────────────────┤
│        메인 콘텐츠            │
├──────┬──────┬──────┬────────┤
│ 달력  │ 목록  │ 통계  │ 설정  │
└──────┴──────┴──────┴────────┘
```

### 탭 1: 달력
- 월간 캘린더 그리드
- 거래 있는 날짜에 점(dot) 표시
- 날짜 탭 → 하단에 해당 일 거래 목록
- 상단에 당월 잔액 표시

### 탭 2: 목록
- 당월 거래 시간순 리스트
- 스와이프로 삭제
- 탭하여 수정
- FAB 버튼으로 거래 추가

### 탭 3: 통계 (Phase 1에서는 기본만)
- 당월 지출/수입 합계 표시
- 카테고리별 단순 목록 (차트는 Phase 2)

### 탭 4: 설정
- 그룹 관리 (이름변경, 삭제, 공유안내)
- 가계부 관리 (생성, 삭제)
- 최근 변경 이력 (30건)
- 장부정리
- 카테고리 관리

---

## 권한 처리

```swift
// iOS 17+
func requestAccess() async -> Bool {
    if #available(iOS 17, *) {
        return (try? await store.requestFullAccessToEvents()) ?? false
    } else {
        return (try? await store.requestAccess(to: .event)) ?? false
    }
}
```

Info.plist:
```
NSCalendarsFullAccessUsageDescription: 
"가계부 데이터를 캘린더 이벤트로 저장하고, 공유 캘린더를 통해 다른 가족 구성원과 함께 사용합니다."
```

---

## 카테고리 기본값

```swift
let defaultCategories = ["식비", "교통", "생활", "문화", "의료", "교육", 
                          "의류", "미용", "통신", "보험", "급여", "용돈", "이자", "기타"]
```

UserDefaults에 저장, 사용자가 추가/삭제/순서변경 가능.

---

## 파일 구조 (이 구조대로 생성)

```
JidalCE/
├── JidalCEApp.swift
├── App/
│   ├── AppState.swift
│   └── ContentView.swift
├── Domain/Models/
│   ├── JidalGroup.swift
│   ├── Ledger.swift
│   ├── Transaction.swift
│   ├── MonthlySnapshot.swift
│   └── HistoryEntry.swift
├── Data/
│   ├── CalendarStore.swift          // EKEventStore 싱글톤 래퍼
│   ├── GroupRepository.swift        // 캘린더(그룹) CRUD + 선택
│   ├── LedgerRepository.swift       // 가계부 메타 CRUD
│   ├── TransactionRepository.swift  // 거래 CRUD (이벤트 검색 + 메모 파싱/직렬화)
│   ├── SnapshotRepository.swift     // 스냅샷 생성/조회/장부정리
│   └── HistoryRepository.swift      // 히스토리 기록/조회/분할
├── Services/
│   ├── NoteSerializer.swift         // 거래 메모 직렬화 ↔ 파싱 (핵심)
│   ├── HistorySerializer.swift      // 히스토리 메모 직렬화 ↔ 파싱
│   └── BalanceCalculator.swift      // 잔액 계산 (스냅샷 + 라이브)
├── Features/
│   ├── Onboarding/
│   │   ├── CalendarPermissionView.swift
│   │   └── GroupSetupView.swift
│   ├── Calendar/
│   │   ├── CalendarTabView.swift
│   │   ├── CalendarTabViewModel.swift
│   │   └── DayDetailView.swift
│   ├── TransactionList/
│   │   ├── TransactionListView.swift
│   │   └── TransactionListViewModel.swift
│   ├── AddTransaction/
│   │   ├── AddTransactionView.swift
│   │   └── AddTransactionViewModel.swift
│   ├── Statistics/
│   │   └── StatisticsView.swift
│   ├── Settings/
│   │   ├── SettingsRootView.swift
│   │   ├── GroupManagementView.swift
│   │   ├── LedgerManagementView.swift
│   │   ├── BookClosingView.swift
│   │   └── HistoryView.swift
│   └── Shared/
│       ├── CategoryManager.swift
│       └── Components/             // 공통 UI 컴포넌트
└── Support/
    └── Extensions.swift
```

---

## 구현 순서 (이 순서를 따라라)

### Step 1: 기반 레이어
1. `CalendarStore.swift` — EKEventStore 싱글톤, 권한 요청, 이벤트 CRUD 헬퍼
2. `NoteSerializer.swift` — 거래 메모 직렬화/파싱 (반드시 유닛 테스트 작성)
3. `HistorySerializer.swift` — 히스토리 메모 직렬화/파싱
4. 모든 데이터 모델

### Step 2: Repository 레이어
5. `GroupRepository.swift` — 캘린더 생성/선택/삭제
6. `TransactionRepository.swift` — 거래 추가/수정/삭제 (NoteSerializer 사용)
7. `HistoryRepository.swift` — 히스토리 기록/조회
8. `SnapshotRepository.swift` — 스냅샷 자동 생성/조회
9. `LedgerRepository.swift` — 가계부 메타 관리
10. `BalanceCalculator.swift` — 잔액 계산

### Step 3: 온보딩 화면
11. `CalendarPermissionView.swift`
12. `GroupSetupView.swift` (새 캘린더 만들기 + 기존 선택)
13. `AppState.swift` + `ContentView.swift` (라우팅)

### Step 4: 메인 기능 화면
14. `CalendarTabView.swift` — 월간 달력 + 일별 거래
15. `TransactionListView.swift` — 거래 목록
16. `AddTransactionView.swift` — 거래 추가/수정 폼
17. `StatisticsView.swift` — 기본 통계

### Step 5: 설정 & 관리
18. `SettingsRootView.swift`
19. `HistoryView.swift` — 최신 30건
20. `BookClosingView.swift` — 장부정리
21. `GroupManagementView.swift`, `LedgerManagementView.swift`
22. `CategoryManager.swift`

---

## 중요한 기술적 주의사항

### EKEventStore 변경 감지
```swift
NotificationCenter.default.addObserver(
    forName: .EKEventStoreChanged, 
    object: store, 
    queue: .main
) { _ in
    // 데이터 리로드
}
```

### 이벤트 저장 전 re-fetch
동시 편집 충돌 방지를 위해, 이벤트 수정 전에 항상 최신 상태를 다시 가져온 뒤 병합:
```swift
// 저장 전 최신 이벤트 다시 가져오기
guard let freshEvent = store.event(withIdentifier: eventId) else { return }
// freshEvent.notes를 파싱하여 현재 변경사항 병합
```

### EventKit 4년 쿼리 제한
```swift
func fetchEvents(from start: Date, to end: Date, calendar: EKCalendar) -> [EKEvent] {
    var results: [EKEvent] = []
    var chunkStart = start
    let maxSpan: TimeInterval = 3.5 * 365 * 86400
    while chunkStart < end {
        let chunkEnd = min(chunkStart.addingTimeInterval(maxSpan), end)
        let predicate = store.predicateForEvents(withStart: chunkStart, end: chunkEnd, calendars: [calendar])
        results.append(contentsOf: store.events(matching: predicate))
        chunkStart = chunkEnd
    }
    return results
}
```

### 사용자 이름 (작성자)
로그인이 없으므로 기기 이름을 기본 작성자로 사용:
```swift
let authorName = UIDevice.current.name  // 예: "마스터의 iPhone"
// 설정에서 사용자가 닉네임을 변경할 수 있도록 UserDefaults에 저장
```

### 선택된 그룹/가계부 상태 저장
UserDefaults에 마지막 선택한 그룹 calendarIdentifier와 가계부 이름을 저장하여, 앱 재실행 시 복원.

---

## 하지 말 것

- Firebase, CloudKit, CoreData, Realm 등 외부 DB 사용 금지
- 서버 통신 코드 작성 금지
- 로그인/인증 화면 구현 금지
- UIKit 직접 사용 금지 (SwiftUI로만)
- Phase 2/3 기능 (음성 입력, SMS, Siri, 위젯) 구현 금지
- 테스트 데이터를 하드코딩하지 말고 실제 EventKit으로 동작하게 구현

---

## 한국어 UI

모든 UI 텍스트는 한국어로 작성:
- 탭: 달력, 목록, 통계, 설정
- 버튼: 추가, 수정, 삭제, 저장, 취소
- 금액 단위: 원
- 날짜 형식: M월 d일 (E)
- 알림/확인: "정말 삭제하시겠습니까?" 등

---

## 완료 기준

Phase 1 MVP가 완료되었다고 판단하는 기준:
1. 앱 실행 → 캘린더 권한 요청 → 그룹 생성/선택 → 메인 화면 진입 가능
2. 거래 추가 시 캘린더 앱에서 해당 이벤트의 메모를 열면 영수증 스타일로 보임
3. 거래 수정/삭제가 동작하고 히스토리에 기록됨
4. 달력 뷰에서 날짜별 거래 확인 가능
5. 잔액이 스냅샷 + 라이브 계산으로 정확히 표시됨
6. 장부정리 실행 시 스냅샷이 재생성됨
7. 히스토리 화면에서 최신 30건 확인 가능
8. NoteSerializer 유닛 테스트 통과 (직렬화 → 파싱 라운드트립)
