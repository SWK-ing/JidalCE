# Codex Task: Jidal CE — Phase 1 안정화 및 완성

## 현재 상태

Phase 1 MVP 골격이 구현되어 Xcode 빌드 성공 상태다. 아래 파일들이 이미 존재한다:

- AppState.swift, ContentView.swift, JidalCEApp.swift (라우팅)
- CalendarStore.swift, TransactionRepository.swift, HistoryRepository.swift, SnapshotRepository.swift (데이터)
- NoteSerializer.swift (메모 직렬화/파싱)
- CalendarTabView, TransactionListView, AddTransactionView, StatisticsView, SettingsRootView (UI)

## 이번 태스크 목표

1. **iOS 26.0 타겟 정리** — `#available(iOS 17, *)` 분기 전부 제거
2. **핵심 로직 검증 및 버그 수정** — 실제 동작하는 MVP로 만들기
3. **누락된 기능 구현** — 골격에서 빠진 Phase 1 항목 채우기

---

## Task 1: iOS 26 마이그레이션

### 변경사항
- deployment target을 **iOS 26.0**으로 변경 (project.pbxproj)
- 코드 전체에서 `#available(iOS 17, *)`, `#available(iOS 16, *)` 등 분기 제거
- `requestFullAccessToEvents()`만 사용 (else 분기 삭제)
- `requestAccess(to: .event)` 호출 제거
- deprecated API 경고 있으면 iOS 26 기준으로 수정

---

## Task 2: NoteSerializer 검증 및 보완

NoteSerializer는 이 앱의 심장이다. 직렬화 → 파싱 라운드트립이 100% 정확해야 한다.

### 반드시 통과해야 하는 케이스

**직렬화 (Transaction 배열 → String):**
```
입력: [
  Transaction(id: "a1f3", amount: -8500, category: "식비", memo: "점심 김밥천국", time: "12:30", by: "마스터"),
  Transaction(id: "b2e7", amount: -45000, category: "교통", memo: "주유", time: "18:20", by: "마스터"),
  Transaction(id: "c9d2", amount: 15000, category: "급여", memo: "용돈", time: "20:00", by: "배우자")
]

기대 출력:
점심 김밥천국
  -8,500원 | 식비 | 12:30 | 마스터
주유
  -45,000원 | 교통 | 18:20 | 마스터
용돈
  +15,000원 | 급여 | 20:00 | 배우자
──────────
지출 53,500원 (2건) · 수입 15,000원 (1건)
──────────
#a1f3 #b2e7 #c9d2
```

**파싱 (String → Transaction 배열):**
위 출력을 다시 파싱하면 원래 Transaction 배열과 동일해야 함.

### 엣지 케이스 확인
- 금액 0원 거래
- 메모에 파이프(`|`) 포함: "A | B 마트" → 첫 번째 `|`만 구분자가 아니라 뒤에서부터 파싱
- 메모에 `──` 포함 (구분선과 혼동 방지)
- 거래 1건만 있는 이벤트
- 빈 notes (거래 0건 — 이벤트 삭제 상황)
- 금액에 천만 단위 콤마: `-10,000,000원`
- 거래 ID 중복 방지 확인

### 금액 파싱 규칙 명확화
```swift
// "-8,500원" → -8500
// "+15,000원" → 15000
// "-10,000,000원" → -10000000
func parseAmount(_ str: String) -> Int? {
    let cleaned = str
        .replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: "원", with: "")
        .trimmingCharacters(in: .whitespaces)
    return Int(cleaned)
}
```

---

## Task 3: HistorySerializer 검증

### 기록 포맷
```
4/01 12:30 추가 | 점심 김밥천국 -8,500원 | 마스터
4/02 09:15 수정 | 주유 -45,000→-43,000원 | 배우자
4/02 20:00 삭제 | 저녁 치킨 -15,000원 | 마스터
```

### 확인 사항
- 거래 추가/수정/삭제 시 히스토리 라인이 정확히 append 되는가
- 수정 시 이전→이후 금액 형식이 맞는가
- 50KB 초과 시 분할 로직이 동작하는가 (테스트 시 maxSize를 1KB로 낮춰서 검증)
- 당월 + 전월 히스토리를 합쳐서 최신 30건 정렬이 정확한가

---

## Task 4: 스냅샷 & 잔액 로직

### 자동 스냅샷 생성
```
앱 실행 시:
  현재 월 확인 → 전전월 스냅샷 존재 여부 체크
  없으면: 이전 스냅샷 잔액 + 전전월 거래 합산 → 스냅샷 생성
```

### 잔액 계산
```swift
func calculateBalance(calendar: EKCalendar, ledgerName: String) -> Int {
    // 1. 최근 스냅샷 찾기
    // 2. 스냅샷 이후 ~ 오늘까지 거래 합산
    // 3. 스냅샷 잔액 + 합산 = 현재 잔액
}
```

### 장부정리
```
사용자가 시작일 선택 → 전전월까지
→ 해당 범위 스냅샷 전부 삭제
→ 월별 순차 재계산
→ 프로그레스 표시
```

### 확인 사항
- 스냅샷이 **다음 달 1일**에 배치되는가 (2월 마감 → 3월 1일)
- 스냅샷 이벤트 제목이 `__snapshot_{가계부명}__` 형식인가
- 잔액 계산이 스냅샷 잔액 + 라이브 거래로 정확한가
- 장부정리 후 잔액이 변경되는가
- 첫 사용일 감지가 동작하는가

---

## Task 5: 누락 기능 구현 체크리스트

기존 골격에서 빠졌을 수 있는 Phase 1 항목들:

### 데이터 레이어
- [ ] 기존 캘린더 선택 시 `event.url = URL(string: "jidalce://...")` 설정
- [ ] 이벤트 조회 시 `url.scheme == "jidalce"` 필터링
- [ ] 시스템 이벤트 필터: `__snapshot_`, `__history_`, `__meta_` prefix 제외
- [ ] EventKit 4년 쿼리 제한 대응 (3.5년 청크 분할)
- [ ] EKEventStoreChanged notification으로 데이터 리로드
- [ ] 저장 전 이벤트 re-fetch (동시 편집 충돌 최소화)

### 그룹 관리
- [ ] 새 캘린더 생성 시 iCloud source 지정
- [ ] 기존 캘린더 선택 옵션 + 경고 메시지
- [ ] 그룹 이름 변경
- [ ] 그룹 삭제 + 확인 알림

### 가계부 관리
- [ ] 가계부 생성 (메타 이벤트 `__meta_` 생성)
- [ ] 가계부 목록 조회 (이벤트 title distinct, 시스템 이벤트 제외)
- [ ] 가계부 삭제 (일반 + 스냅샷 + 히스토리 + 메타 전부)

### 거래 관리
- [ ] 거래 추가 → 기존 이벤트에 append 또는 새 이벤트 생성
- [ ] 거래 수정 → 메모 파싱 → ID로 찾기 → 수정 → 재직렬화
- [ ] 거래 삭제 → 빈 이벤트면 이벤트 자체 삭제
- [ ] 모든 CRUD에서 히스토리 기록 연동

### UI
- [ ] 달력 뷰: 거래 있는 날짜에 dot 표시
- [ ] 달력 뷰: 날짜 탭 시 해당 일 거래 목록
- [ ] 달력 뷰: 상단에 당월 잔액 표시
- [ ] 목록 뷰: 스와이프 삭제
- [ ] 목록 뷰: 탭하여 수정 화면 이동
- [ ] 거래 추가 화면: 금액, 카테고리, 메모, 수입/지출, 날짜, 가계부 선택
- [ ] 통계: 당월 지출/수입 합계
- [ ] 설정: 히스토리 화면 (최신 30건)
- [ ] 설정: 장부정리 화면 (시작일 선택 + 프로그레스)
- [ ] 설정: 카테고리 관리

### 사용자 이름
- [ ] UserDefaults에 닉네임 저장 (기본값: `UIDevice.current.name`)
- [ ] 설정에서 닉네임 변경 가능
- [ ] 거래 기록 시 닉네임을 작성자로 사용

### 상태 유지
- [ ] 마지막 선택 그룹/가계부를 UserDefaults에 저장
- [ ] 앱 재실행 시 복원

---

## Task 6: 카테고리 관리

```swift
let defaultCategories = ["식비", "교통", "생활", "문화", "의료", "교육", 
                          "의류", "미용", "통신", "보험", "급여", "용돈", "이자", "기타"]
```

- UserDefaults에 저장
- 추가/삭제/순서변경 UI
- 거래 추가 화면에서 카테고리 선택 연동

---

## 구현 우선순위

이 순서대로 처리하라:

1. **iOS 26 타겟 정리** (Task 1) — 가장 먼저
2. **NoteSerializer 정확성** (Task 2) — 이게 틀리면 모든 게 틀림
3. **거래 CRUD 실동작** (Task 5 거래 관리) — 핵심 기능
4. **히스토리 연동** (Task 3) — CRUD에 히스토리 append
5. **스냅샷 & 잔액** (Task 4) — 잔액 표시
6. **나머지 UI** (Task 5 UI 항목들)
7. **카테고리/사용자/상태 유지** (Task 5, 6)

---

## 하지 말 것 (이전과 동일)

- Firebase, CloudKit, CoreData, Realm 사용 금지
- 서버 통신 코드 금지
- 로그인/인증 화면 금지
- UIKit 직접 사용 금지
- Phase 2/3 기능 (음성, SMS, Siri, 위젯) 금지
- 하드코딩 테스트 데이터 금지

## 한국어 UI (이전과 동일)

모든 텍스트 한국어. 금액 단위 원. 날짜 M월 d일 (E).

---

## 완료 기준

1. iOS 26.0 타겟으로 빌드 성공, `#available` 분기 없음
2. NoteSerializer 직렬화 → 파싱 라운드트립 정확 (엣지 케이스 포함)
3. 시뮬레이터에서 거래 추가 → 기본 캘린더 앱에서 메모 확인 → 영수증 스타일로 보임
4. 거래 수정/삭제 후 히스토리에 기록됨
5. 달력 뷰에서 날짜별 거래 확인 + 잔액 표시
6. 장부정리 실행 → 스냅샷 재생성 → 잔액 변경 확인
7. 히스토리 화면에서 최신 30건 확인
8. 카테고리 추가/삭제 가능
9. 앱 재실행 시 마지막 선택 그룹/가계부 복원
