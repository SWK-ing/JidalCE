# Codex Task: Jidal CE — Step 3: Phase 1 마무리

## 현재 상태

Step 2까지 완료. 빌드 성공, 워닝 0건. 핵심 데이터 레이어(NoteSerializer, TransactionRepository, HistoryRepository, SnapshotRepository)가 안정화되었다. 이번 스텝에서 Phase 1의 남은 항목을 전부 마무리한다.

---

## Task 1: iOS 26 deployment target 확인

프로젝트 전체에서 아래가 없는지 확인하고 있으면 제거:
- `#available(iOS` 분기문
- `@available(iOS` 어노테이션
- `requestAccess(to: .event)` (구버전 API)

deployment target이 iOS 26.0인지 project.pbxproj에서 확인.

---

## Task 2: UI 완성 — 달력 탭

### 2-1. 거래 있는 날짜에 dot 표시

```
월간 캘린더 그리드에서:
  → 해당 월의 모든 거래 이벤트를 fetch
  → 날짜별로 이벤트 존재 여부 Set<Date> 생성
  → 날짜 셀 아래에 작은 원형 dot 표시
```

### 2-2. 날짜 탭 시 해당 일 거래 목록

```
날짜 셀 탭 → 선택 날짜 상태 변경
  → 달력 아래 영역에 해당 일의 거래 리스트 표시
  → 거래 없으면 "거래 없음" 표시
  → 거래 탭 시 수정 화면 이동
```

### 2-3. 당월 잔액 표시

```
달력 상단에:
  이번 달 잔액: 2,500,000원
  이번 달 지출: -350,000원  수입: +5,000,000원

BalanceCalculator로 계산:
  최근 스냅샷 잔액 + 라이브 거래 합산
```

---

## Task 3: UI 완성 — 거래 목록 탭

### 3-1. 스와이프 삭제

```swift
.swipeActions(edge: .trailing) {
    Button(role: .destructive) {
        // TransactionRepository.deleteTransaction()
        // HistoryRepository에 삭제 기록
    } label: {
        Label("삭제", systemImage: "trash")
    }
}
```

### 3-2. 탭하여 수정

```
거래 셀 탭 → AddTransactionView를 수정 모드로 열기
  → 기존 값 pre-fill
  → 저장 시 TransactionRepository.updateTransaction()
```

### 3-3. 당월 기준 표시

```
목록 상단: "4월" ← 월 전환 가능
거래를 날짜 내림차순 표시 (최신 먼저)
각 날짜 섹션 헤더: "4월 15일 (화)"
```

---

## Task 4: UI 완성 — 통계 탭 (기본)

Phase 1에서는 차트 없이 텍스트 기반으로:

```
┌─────────────────────────┐
│  4월 통계                │
├─────────────────────────┤
│                         │
│  총 지출    350,000원    │
│  총 수입  5,000,000원    │
│  잔액    2,500,000원     │
│                         │
│  ── 카테고리별 지출 ──    │
│  식비       120,000원    │
│  교통        85,000원    │
│  생활        95,000원    │
│  문화        50,000원    │
│                         │
│  ── 카테고리별 수입 ──    │
│  급여     5,000,000원    │
│                         │
└─────────────────────────┘
```

카테고리별 합계는 해당 월 거래를 category로 grouping해서 계산.

---

## Task 5: UI 완성 — 설정 탭

### 5-1. 히스토리 화면

```
설정 → "최근 변경 이력" 탭 → HistoryView 표시

HistoryRepository에서 당월+전월 히스토리 로드
최신순 30건 표시

각 항목 표시:
  4/01 12:30  추가
  점심 김밥천국 -8,500원  마스터

  4/02 09:15  수정
  주유 -45,000→-43,000원  배우자

하단 안내:
  "이전 이력은 캘린더 앱에서 히스토리 이벤트를 확인하세요"
```

### 5-2. 장부정리 화면 (BookClosingView)

```
┌─────────────────────────────┐
│  장부정리                     │
├─────────────────────────────┤
│                             │
│  가계부: 생활비               │
│                             │
│  정리 시작: [2024년 1월 ▼]   │
│  정리 종료: 2026년 2월 (자동) │
│                             │
│  ℹ️ 가장 오래된 기록:         │
│     2024년 1월               │
│                             │
│  [ 장부정리 시작 ]            │
│                             │
├─────────────────────────────┤
│  (실행 중일 때)               │
│                             │
│  장부정리 진행 중...           │
│  2024년 1월 ✓               │
│  2024년 2월 ✓               │
│  2024년 3월 ━━━━━━░░░░      │
│  ...                        │
│  2026년 2월                  │
│                             │
│  ── 완료 시 ──               │
│  정리 완료! 잔액: 2,500,000원 │
│                             │
└─────────────────────────────┘
```

구현 포인트:
- 시작월 Picker: 첫 사용일 ~ 전전월 범위
- 종료월: 전전월 자동 (변경 불가, 텍스트로 표시)
- 첫 사용일은 `SnapshotRepository.detectFirstRecordDate()` 사용
- 실행 중 `@Published var progress` 로 월별 진행 상태 표시
- SnapshotRepository의 장부정리 로직 호출
- 완료 시 새 잔액 표시

### 5-3. 그룹 이름 변경

```
설정 → 그룹 관리 → 이름 변경
  → TextField에 현재 이름 표시
  → 저장 시 calendar.title = newName → eventStore.saveCalendar()
```

### 5-4. 카테고리 관리

```
설정 → 카테고리 관리

기본값: ["식비", "교통", "생활", "문화", "의료", "교육",
        "의류", "미용", "통신", "보험", "급여", "용돈", "이자", "기타"]

기능:
  - 추가: 하단 텍스트필드 + 추가 버튼
  - 삭제: 스와이프
  - 순서변경: EditButton + onMove
  - UserDefaults에 저장

CategoryManager.swift:
  - shared 싱글톤
  - categories: [String] (UserDefaults 연동)
  - add/remove/move 메서드
  - 거래 추가 화면에서 이 목록 사용
```

### 5-5. 닉네임 설정

```
설정 → 닉네임

기본값: UIDevice.current.name (예: "마스터의 iPhone")
UserDefaults에 저장
거래 기록 시 이 닉네임이 작성자(by)로 들어감

TextField로 편집 가능
```

---

## Task 6: 이벤트 식별 보강

### 모든 이벤트에 URL 스킴 설정

```swift
// 거래 이벤트 생성/수정 시
event.url = URL(string: "jidalce://transaction/\(ledgerName)")

// 스냅샷 이벤트
event.url = URL(string: "jidalce://snapshot/\(ledgerName)")

// 히스토리 이벤트
event.url = URL(string: "jidalce://history/\(ledgerName)")

// 메타 이벤트
event.url = URL(string: "jidalce://meta/\(ledgerName)")
```

### 조회 시 필터링

기존 캘린더를 사용하는 경우를 대비하여, 이벤트 조회 시 항상 Jidal 이벤트만 필터:

```swift
func isJidalEvent(_ event: EKEvent) -> Bool {
    return event.url?.scheme == "jidalce"
}
```

CalendarStore 또는 각 Repository의 fetch 메서드에서 이 필터를 적용하고 있는지 확인. 빠져 있으면 추가.

---

## Task 7: EKEventStoreChanged 대응

```swift
// AppState 또는 CalendarStore에서:
NotificationCenter.default.addObserver(
    forName: .EKEventStoreChanged,
    object: calendarStore.store,
    queue: .main
) { [weak self] _ in
    self?.reloadCurrentData()
}
```

앱이 foreground로 돌아왔을 때 또는 다른 기기에서 캘린더 변경 시 자동 리로드. 현재 표시 중인 월/날짜의 데이터를 다시 fetch.

---

## Task 8: 거래 추가 화면 점검

AddTransactionView에 아래가 모두 동작하는지 확인:

- [ ] 금액 입력 (숫자 키패드, 천 단위 콤마 자동 표시)
- [ ] 수입/지출 토글
- [ ] 카테고리 선택 (CategoryManager.categories 연동)
- [ ] 메모 입력
- [ ] 날짜 선택 (DatePicker, 기본값: 오늘)
- [ ] 가계부 선택 (현재 그룹의 가계부 목록)
- [ ] 저장 버튼 → TransactionRepository.addTransaction() + 히스토리 기록
- [ ] 수정 모드: 기존 값 pre-fill + 저장 시 updateTransaction()
- [ ] 취소 버튼

---

## 구현 우선순위

1. **Task 1**: iOS 26 확인 (1분)
2. **Task 6**: URL 스킴 보강 (데이터 무결성)
3. **Task 7**: EKEventStoreChanged (데이터 리로드)
4. **Task 2**: 달력 탭 완성
5. **Task 3**: 목록 탭 완성
6. **Task 8**: 거래 추가 화면 점검
7. **Task 4**: 통계 탭
8. **Task 5**: 설정 (히스토리, 장부정리, 그룹, 카테고리, 닉네임)

---

## 하지 말 것

- Phase 2/3 기능 (음성, SMS, Siri, 위젯, 차트) 금지
- UIKit 사용 금지
- 외부 패키지 추가 금지
- 서버 통신 금지
- 테스트 타깃 생성 금지 (이번 스텝 범위 아님)

---

## 완료 기준

1. 달력 탭: 거래 있는 날짜에 dot, 날짜 탭 시 거래 목록, 잔액 표시
2. 목록 탭: 스와이프 삭제, 탭 수정, 월별 표시
3. 통계 탭: 당월 지출/수입 합계 + 카테고리별 합계
4. 설정: 히스토리 30건, 장부정리 프로그레스, 그룹 이름 변경, 카테고리 CRUD, 닉네임
5. 모든 이벤트에 jidalce:// URL 스킴 설정됨
6. EKEventStoreChanged로 데이터 자동 리로드
7. 거래 추가/수정 화면이 모든 필드 정상 동작
8. 빌드 성공, 워닝 0건
