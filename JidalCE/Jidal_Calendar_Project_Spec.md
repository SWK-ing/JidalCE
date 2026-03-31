# Jidal Calendar Edition — 프로젝트 정의서 v1.1

## 1. 프로젝트 개요

- **앱 이름**: 지갑의달인 Calendar Edition (Jidal CE)
- **플랫폼**: iOS, SwiftUI
- **백엔드**: 없음 (서버리스)
- **데이터 저장소**: iOS 네이티브 캘린더 (EventKit)
- **데이터 공유**: iCloud 캘린더 공유
- **인증**: 없음 (기기 소유자 = 사용자)

### 핵심 컨셉

Firebase 기반이었던 기존 Jidal 앱의 핵심 기능(가계부 기록, 공유, 통계)을 iOS 기본 캘린더 인프라만으로 구현한다. 로그인 없이, 서버 없이, 폰의 기본 기능만으로 공유 가계부를 운영한다.

### 기존 Jidal과의 차이

| 항목 | 기존 Jidal (Firebase) | Jidal CE (Calendar) |
|---|---|---|
| 인증 | Google/Apple Sign-In | 없음 |
| 데이터 저장 | Firestore | iOS 캘린더 이벤트 |
| 멀티유저 공유 | Firestore 실시간 동기화 | iCloud 캘린더 공유 |
| 오프라인 지원 | Firestore 캐시 | 네이티브 캘린더 (완전 오프라인) |
| 서버 의존성 | Firebase 서버 | 없음 |
| 앱 없이 데이터 확인 | 불가 | 기본 캘린더 앱에서 확인 가능 |

---

## 2. 데이터 아키텍처

### 캘린더 ↔ 앱 개념 매핑

| 앱 개념 | 캘린더 매핑 | 식별 방법 | 예시 |
|---|---|---|---|
| 그룹 (Household) | EKCalendar | 캘린더 이름 | "우리집", "커플" |
| 가계부 (Ledger) | EKEvent 제목 | 이벤트 title | "생활비", "여행경비" |
| 일일 거래 묶음 | EKEvent 1개 | 날짜 + 제목 | 3/15 "생활비" |
| 개별 거래 | notes 내 파싱 라인 | 거래 ID (#xxxx) | 메모 내 1개 블록 |
| 월간 스냅샷 | 전용 EKEvent | 제목 prefix `__snapshot_` | `__snapshot_생활비__` |
| 월간 변경 이력 | 전용 EKEvent | 제목 prefix `__history_` | `__history_생활비_2026-04__` |

### 캘린더에서 실제로 보이는 모습

```
📅 캘린더: 우리집

  3월 1일
    __snapshot_생활비__          ← 2월 마감 스냅샷
    __history_생활비_2026-02__  ← 2월 변경 이력 (마감)
    __history_생활비_2026-03__  ← 3월 변경 이력 (진행 중)
    
  3월 15일 (토)
    생활비                       ← 거래 3건 포함
    여행경비                     ← 거래 1건 포함

  3월 16일 (일)
    생활비                       ← 거래 2건 포함

  4월 1일
    __snapshot_생활비__          ← 3월 마감 스냅샷
    __history_생활비_2026-03__  ← 3월 변경 이력 (마감)
    __history_생활비_2026-04__  ← 4월 변경 이력 (진행 중)
    생활비                       ← 거래 1건 포함
```

### 이벤트 속성 활용

| EKEvent 속성 | 용도 |
|---|---|
| `calendar` | 그룹 식별 |
| `title` | 가계부 이름 |
| `startDate` / `endDate` | 거래 날짜 (All-day event) |
| `notes` | 거래 내역 (구조화 텍스트) |
| `isAllDay` | 항상 `true` |
| `calendarItemIdentifier` | 이벤트 유니크 ID (앱 내부 참조용) |

---

## 3. 메모 포맷 사양

### 일반 거래 이벤트 메모

사람이 읽었을 때 영수증처럼 보이면서, 앱에서 정확하게 파싱 가능한 구조.

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

### 파싱 규칙

1. 들여쓰기 없는 줄 = 거래 메모(설명)
2. 들여쓰기(`  `, 공백 2칸) 시작 줄 = 데이터 라인
3. 데이터 라인 포맷: `  {부호}{금액}원 | {카테고리} | {시간} | {작성자}`
   - `+` = 수입, `-` = 지출
   - 금액에 천 단위 콤마 포함
   - 시간은 `HH:mm` 24시간제
4. `──`로 시작하는 줄 = 구분선 (이후는 요약 영역)
5. 첫 번째 구분선 ~ 두 번째 구분선 사이 = 요약 텍스트 (표시용, 파싱 무시)
6. 마지막 줄 `#xxxx #yyyy ...` = 거래 ID 목록 (메모-데이터 쌍과 순서 1:1 매칭)

### 거래 ID 생성 규칙

- 4자리 hex 랜덤 (`UUID().uuidString.prefix(4).lowercased()`)
- 같은 이벤트 내 중복 불가
- 거래 추가 시 생성, 이후 변경 없음

### 파싱 결과 데이터 모델

```swift
struct ParsedTransaction {
    let id: String          // "a1f3"
    let memo: String        // "점심 김밥천국"
    let amount: Int         // -8500 (음수=지출, 양수=수입)
    let category: String    // "식비"
    let time: String        // "12:30"
    let by: String          // "마스터"
}
```

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

### 스냅샷 파싱 규칙

1. 이벤트 제목이 `__snapshot_` 으로 시작하고 `__`로 끝남 → 스냅샷 이벤트
2. `이월:` 뒤의 금액 = 해당 월 시작 잔액
3. `잔액:` 뒤의 금액 = 해당 월 마감 잔액 (= 다음 달 이월액)
4. `#snapshot:YYYY-MM` = 마감 대상 연월
5. 스냅샷 이벤트 날짜 = 마감 대상 월의 다음 달 1일 (2월 마감 → 3월 1일에 위치)

### 히스토리 이벤트 메모

거래의 추가/수정/삭제 변경 이력을 월별로 기록한다.

```
4/01 12:30 추가 | 점심 김밥천국 -8,500원 | 마스터
4/01 18:20 추가 | 주유 -45,000원 | 마스터
4/02 09:15 수정 | 주유 -45,000→-43,000원 | 배우자
4/02 20:00 삭제 | 저녁 치킨 -15,000원 | 마스터
4/05 11:00 추가 | 마트 장보기 -67,200원 | 배우자
...
──────────
4월: 추가 15건, 수정 3건, 삭제 1건
──────────
#history:2026-04
```

### 히스토리 파싱 규칙

1. 이벤트 제목 포맷: `__history_{가계부명}_{YYYY-MM}__`
2. 히스토리 이벤트 날짜 = 대상 월의 1일 (4월 이력 → 4월 1일에 위치)
3. 각 라인 포맷: `{M/dd} {HH:mm} {동작} | {메모} {금액}원 | {작성자}`
4. 동작 종류: `추가`, `수정`, `삭제`
5. 수정의 경우 변경 전후: `{이전금액}→{이후금액}원`
6. `──` 이후 = 요약 (표시용, 파싱 무시)
7. `#history:YYYY-MM` = 대상 연월

### 히스토리 기록 시점

| 사용자 동작 | 히스토리 기록 |
|---|---|
| 거래 추가 | `{날짜} {시간} 추가 \| {메모} {금액}원 \| {작성자}` |
| 거래 수정 | `{날짜} {시간} 수정 \| {메모} {이전}→{이후}원 \| {작성자}` |
| 거래 삭제 | `{날짜} {시간} 삭제 \| {메모} {금액}원 \| {작성자}` |

### 히스토리 이벤트 자동 분할

월간 히스토리 notes가 50KB를 초과할 경우 반월 단위로 자동 분할한다.

```swift
func appendHistory(event: EKEvent, entry: String) {
    let maxSize = 50_000  // 50KB 안전선
    
    if (event.notes?.utf8.count ?? 0) + entry.utf8.count > maxSize {
        // 새 히스토리 이벤트 생성: __history_생활비_2026-04-B__
        // suffix -B, -C 등으로 분할
    } else {
        event.notes = (event.notes ?? "") + "\n" + entry
        try store.save(event, span: .thisEvent)
    }
}
```

일 평균 5건 거래 기준 월 ~170건(추가+수정+삭제), 약 10KB 수준이므로 일반 사용에서 분할이 발생할 가능성은 낮다. 헤비 유저(일 20건+) 대비 안전장치.

### 히스토리 UI 표시

앱 내 히스토리 화면은 **당월 + 전월 히스토리를 합쳐서 최신순 30건**만 표시한다.

```
표시 로직:
1. 당월 히스토리 이벤트 로드   (__history_생활비_2026-04__)
2. 전월 히스토리 이벤트 로드   (__history_생활비_2026-03__)
3. 분할 이벤트 있으면 함께 로드 (-B, -C 등)
4. 모든 히스토리 라인 시간순 병합
5. 최신순 정렬
6. 상위 30건만 표시
7. 하단 안내: "이전 이력은 캘린더 앱에서 히스토리 이벤트를 확인하세요"
```

전월까지 합치는 이유: 월초에도 충분한 이력이 표시되도록 하기 위함. 이벤트 2개(분할 제외)만 파싱하므로 성능 부담 없음.

---

## 4. CRUD 상세 흐름

### 거래 추가

```
1. 입력: 금액, 카테고리, 메모, 가계부명
2. 해당 날짜 + 해당 가계부명의 이벤트 검색
   → 그룹 캘린더 내에서 predicateForEvents(날짜 범위: 당일)
   → title == 가계부명 && title에 __snapshot_, __history_, __meta_ 미포함
3-A. 이벤트 존재:
   → notes 파싱 → transactions 배열에 append
   → 요약 라인 재계산 → ID 라인에 추가
   → notes 재직렬화 → event.save
3-B. 이벤트 미존재:
   → 새 All-day 이벤트 생성 (calendar: 그룹, title: 가계부명)
   → notes에 거래 1건 직렬화 → event.save
4. 히스토리 이벤트에 "추가" 라인 append
```

### 거래 수정

```
1. 해당 날짜 + 가계부명으로 이벤트 검색
2. notes 파싱 → ID로 대상 거래 찾기
3. 변경 전 금액 보존
4. 필드 수정 → notes 재직렬화 → event.save
5. 히스토리 이벤트에 "수정" 라인 append (이전→이후 금액 포함)
```

### 거래 삭제

```
1. 해당 날짜 + 가계부명으로 이벤트 검색
2. notes 파싱 → ID로 대상 거래 제거
3-A. 남은 거래 있음: notes 재직렬화 → event.save
3-B. 남은 거래 없음: 이벤트 자체 삭제
4. 히스토리 이벤트에 "삭제" 라인 append
```

### 가계부(Ledger) 목록 조회

```
1. 그룹 캘린더의 최근 N개월 이벤트 전체 fetch
2. title 목록에서 distinct 추출
3. __snapshot_, __history_, __meta_ prefix 제외
4. 기존 캘린더 사용 시 url.scheme == "jidalce" 필터 적용
→ 결과: ["생활비", "여행경비", "비상금"]
```

### 월간 거래 조회

```
1. predicateForEvents(해당 월 1일 ~ 말일, 그룹 캘린더)
2. title == 가계부명인 이벤트 필터
3. 각 이벤트의 notes 파싱 → 거래 배열 합산
→ 결과: 해당 월의 전체 거래 리스트
```

---

## 5. 잔액 및 스냅샷 전략

### 기본 원칙

- 스냅샷은 **전전월**까지만 생성 (확정된 데이터)
- **전월 + 당월**은 항상 라이브 계산 (수정 가능성 있는 데이터)
- 잔액 = 최근 스냅샷 잔액 + 라이브 기간 거래 합산

### 잔액 계산 흐름

```
오늘: 2026년 4월 15일

잔액 = 스냅샷(~2월말) + 3월 거래 합산 + 4월 거래 합산
       ━━━━━━━━━━━━━    ━━━━━━━━━━━━━━━━━━━━━━━━━━━
       이벤트 1개 읽기    최대 ~60개 이벤트 파싱 (2개월분)
```

### 자동 스냅샷 생성

```
앱 실행 시 (월 1회 체크):
  현재 월 = 4월
  전전월 = 2월
  → 2월 스냅샷 존재 여부 확인
    → 없으면:
      1월 스냅샷 잔액 가져오기 (없으면 0)
      + 2월 전체 거래 합산
      → 2월 스냅샷 이벤트 생성 (3월 1일에 배치)
    → 있으면:
      아무것도 안 함
```

### 장부정리 기능 (수동 스냅샷 재생성)

사용자가 과거 거래를 수정했거나, 스냅샷 데이터에 이상이 생겼을 때 사용.

#### 동작 방식

```
[장부정리 화면]

  정리 시작일: 2024년 1월        ← 사용자 선택
  정리 종료일: 2026년 2월        ← 전전월 (자동, 변경 불가)

  가이드: "이 캘린더의 가장 오래된 기록은 2024년 1월입니다."
          ← 첫 사용일 자동 감지하여 표시

  [ 장부정리 시작 ]
```

#### 처리 순서

```
1. 시작일 ~ 종료월 범위의 기존 스냅샷 이벤트 전부 삭제
2. 시작일부터 월별로 순차 재계산:
   - 1월: 이월 0원 + 1월 거래 합산 → 1월 스냅샷 생성
   - 2월: 1월 잔액 + 2월 거래 합산 → 2월 스냅샷 생성
   - ...반복...
   - 종료월까지 완료
3. 완료 메시지 + 새 잔액 표시
```

#### 첫 사용일 감지

```swift
func detectFirstRecordDate(calendar: EKCalendar) -> Date? {
    // 4년 단위로 과거 탐색 (EventKit 쿼리 제한)
    // 가장 오래된 이벤트의 startDate 반환
    // 스냅샷 이벤트는 제외
}
```

#### 장부정리 중 프로그레스

```
장부정리 진행 중...
  2024년 1월 ✓
  2024년 2월 ✓
  2024년 3월 ━━━━━━░░░░
  ...
```

### EventKit 4년 쿼리 제한 대응

이벤트 조회 시 predicate의 최대 범위가 4년이므로, 4년 이상의 데이터를 다룰 때는 청크 분할로 처리한다.

```swift
func fetchEvents(from start: Date, to end: Date,
                 calendar: EKCalendar) -> [EKEvent] {
    var results: [EKEvent] = []
    var chunkStart = start
    let maxSpan: TimeInterval = 3.5 * 365 * 86400  // 안전하게 3.5년

    while chunkStart < end {
        let chunkEnd = min(chunkStart.addingTimeInterval(maxSpan), end)
        let predicate = store.predicateForEvents(
            withStart: chunkStart, end: chunkEnd, calendars: [calendar]
        )
        results.append(contentsOf: store.events(matching: predicate))
        chunkStart = chunkEnd
    }
    return results
}
```

---

## 6. 그룹 관리

### 캘린더 선택 방식

그룹은 캘린더 1개에 대응한다. 새 캘린더를 만들거나, 기존 캘린더를 선택할 수 있다.

#### 온보딩 / 그룹 추가 화면

```
┌─────────────────────────────────┐
│  가계부에 사용할 캘린더 선택       │
├─────────────────────────────────┤
│                                 │
│  ＋ 새 캘린더 만들기 (권장)       │
│                                 │
│  ── 또는 기존 캘린더 사용 ──      │
│                                 │
│  ⚠️ 기존 일정과 가계부 기록이      │
│     함께 표시됩니다              │
│                                 │
│  ○ 우리집                       │
│  ○ 가족 공유                     │
│  ○ 개인                         │
│                                 │
│  ── 기타 계정 ──                 │
│  ○ Gmail 캘린더                  │
│                                 │
└─────────────────────────────────┘
```

#### 새 캘린더 만들기 (권장)

```
1. 새 EKCalendar 생성 (source: iCloud)
2. calendar.title = 그룹 이름 (예: "우리집")
3. calendar.cgColor = 그룹 색상
4. eventStore.saveCalendar()
```

- 가계부 전용이므로 기존 일정과 혼재 없음
- 모든 이벤트가 가계부 데이터라고 확신할 수 있음

#### 기존 캘린더 선택

```
1. eventStore.calendars(for: .event)로 전체 캘린더 목록 표시
2. iCloud 캘린더 우선 표시 (공유 가능한 것만)
3. 사용자 선택 시 경고 표시:
   "기존 일정과 가계부 기록이 함께 표시됩니다"
4. 선택한 캘린더를 그룹으로 등록
```

- 이미 가족과 공유된 캘린더를 바로 활용할 수 있음 (공유 재설정 불필요)
- 기존 일정과 가계부 이벤트가 혼재됨

#### 기존 캘린더 사용 시 이벤트 식별

기존 캘린더에는 가계부 외 일반 일정이 섞여 있으므로, 가계부 이벤트를 확실히 구분해야 한다.

```swift
// 가계부 이벤트 식별 방법: event.url에 앱 스킴 삽입
let event = EKEvent(eventStore: store)
event.url = URL(string: "jidalce://ledger/생활비")

// 조회 시 필터링
func isJidalEvent(_ event: EKEvent) -> Bool {
    return event.url?.scheme == "jidalce"
}
```

시스템 이벤트(`__snapshot_`, `__history_`, `__meta_`)도 동일하게 url 스킴을 설정한다. 이 방식은 새 캘린더에도 적용하여 일관성을 유지한다.

### 그룹 공유 (멀티유저)

```
iCloud 캘린더 공유 기능을 활용:
  1. 설정 > 캘린더 > 해당 캘린더 > 사람 추가
  2. 또는 앱 내에서 캘린더 공유 안내 화면 제공
  3. 공유받은 사람의 캘린더에 자동으로 나타남
  4. 양쪽 모두 이벤트 추가/수정/삭제 가능
```

> **참고**: EventKit API로 프로그래밍적 공유 초대는 불가. 사용자가 직접 iOS 캘린더 설정에서 공유해야 함. 앱에서는 이 과정을 안내하는 가이드 화면을 제공한다.

### 그룹 삭제

```
1. 확인 알림: "이 그룹의 모든 가계부와 거래 기록이 삭제됩니다"
2. eventStore.removeCalendar(calendar, commit: true)
```

---

## 7. 가계부 관리

### 가계부 생성

```
1. 이름 입력 (예: "여행경비")
2. 해당 그룹 캘린더에 이 이름의 이벤트가 존재하는지 확인 (중복 방지)
3. 가계부 자체는 별도 저장 불필요 — 이벤트가 생기면 자동으로 가계부가 존재
4. 가계부 메타데이터(아이콘, 색상, 통화 등)는 별도 설정 이벤트에 저장
```

### 가계부 메타데이터 저장

가계부별 설정(아이콘, 색상, 통화 등)은 캘린더 이벤트로 저장:

```
이벤트 제목: __meta_생활비__
날짜: 캘린더 내 가장 오래된 날 (또는 고정 날짜)
메모:
  아이콘: 💰
  색상: blue
  통화: KRW
  생성일: 2024-01-15
  ──────────
  #meta:생활비
```

### 가계부 이름 변경

```
1. 해당 가계부의 모든 이벤트 title 업데이트
2. 스냅샷 이벤트 title도 업데이트
3. 메타 이벤트 title도 업데이트
→ 기간이 길면 4년 청크 분할 적용
```

### 가계부 삭제

```
1. 확인 알림
2. 해당 title의 모든 이벤트 삭제 (일반 + 스냅샷 + 히스토리 + 메타)
```

---

## 8. 동시 편집 및 충돌 처리

### iCloud 동기화 특성

- 동기화 지연: 수 초 ~ 수 분
- 충돌 해결: last-write-wins (마지막 저장이 우선)
- 실시간 리스너: 없음 (Firestore와 다름)

### 충돌 시나리오 및 대응

| 시나리오 | 발생 확률 | 결과 | 대응 |
|---|---|---|---|
| 같은 날 같은 가계부에 동시 추가 | 낮음 | 한쪽 거래 유실 가능 | 앱 실행 시 동기화 대기 후 로드 |
| 한쪽이 수정, 한쪽이 추가 | 매우 낮음 | 수정 or 추가 중 하나 유실 | 수용 (가정용 가계부 수준) |
| 한쪽이 삭제, 한쪽이 수정 | 극히 낮음 | 삭제 우선 | 수용 |

### 앱 레벨 보완

```
1. 앱 foreground 진입 시 EKEventStoreChanged notification 수신
2. 변경 감지 시 현재 화면 데이터 리로드
3. 저장 전 이벤트 최신 상태 re-fetch 후 병합 시도
```

---

## 9. 화면 구성

### 메인 탭 구조

```
┌─────────────────────────────┐
│  [그룹선택 ▼]  [가계부선택 ▼]│
├─────────────────────────────┤
│                             │
│        메인 콘텐츠 영역       │
│                             │
├──────┬──────┬──────┬────────┤
│ 달력  │ 목록  │ 통계  │ 설정  │
└──────┴──────┴──────┴────────┘
```

### 탭 1: 달력

- 월간 캘린더 뷰
- 날짜 탭 시 해당 일의 거래 목록 표시
- 거래 있는 날짜에 점 표시
- 당월 잔액 표시 (스냅샷 + 라이브 계산)

### 탭 2: 목록

- 최근 거래 시간순 리스트
- 스와이프 삭제 / 탭하여 수정
- 거래 추가 FAB 버튼

### 탭 3: 통계

- 월간 지출/수입 흐름 차트
- 카테고리별 파이 차트
- 누적 잔액 추이 (스냅샷 기반)
- 예산 관리 (로컬 UserDefaults 저장)

### 탭 4: 설정

- 그룹 관리 (생성, 이름변경, 삭제, 공유안내)
- 가계부 관리 (생성, 편집, 삭제, 순서변경)
- 최근 변경 이력 (당월+전월 최신 30건)
- 장부정리
- 카테고리 관리
- 앱 정보

---

## 10. 거래 입력 방법

### 수동 입력

- 금액, 카테고리, 메모, 수입/지출 구분
- 날짜 선택 (기본값: 오늘)
- 가계부 선택 (기본값: 현재 선택된 가계부)

### 음성 입력 (Phase 2)

- 기존 Jidal의 AI 음성 파싱 로직 재활용
- "점심 김밥천국 팔천오백원" → 파싱 → 거래 생성

### SMS 파싱 (Phase 2)

- 기존 Jidal의 SMS 파싱 로직 재활용
- 카드 결제 문자 → 파싱 → 거래 생성

---

## 11. 권한 및 Info.plist

### 필수 권한

| 권한 | 키 | 사유 |
|---|---|---|
| 캘린더 전체 접근 | `NSCalendarsFullAccessUsageDescription` | 이벤트 읽기/쓰기 |

### iOS 17+ 권한 모델

```swift
// iOS 17+: requestFullAccessToEvents()
// iOS 16-: requestAccess(to: .event)

func requestAccess() async -> Bool {
    if #available(iOS 17, *) {
        return (try? await store.requestFullAccessToEvents()) ?? false
    } else {
        return (try? await store.requestAccess(to: .event)) ?? false
    }
}
```

### 불필요한 권한 (기존 Jidal 대비 제거)

- Firebase Auth 관련 권한 전부 불필요
- Google Sign-In 관련 URL scheme 불필요
- Keychain 접근 불필요

---

## 12. 앱 라우팅 (기존 Jidal 대비 단순화)

### 기존 Jidal

```
authentication → householdOnboarding → main
```

### Jidal CE

```
calendarPermission → groupSetup → main
```

| 단계 | 조건 | 화면 |
|---|---|---|
| `calendarPermission` | 캘린더 접근 권한 미허용 | 권한 요청 안내 |
| `groupSetup` | 사용 가능한 그룹 캘린더 없음 | 새 캘린더 만들기 (권장) 또는 기존 캘린더 선택 |
| `main` | 그룹 존재 | 메인 탭 화면 |

---

## 13. 데이터 모델 (앱 내부)

```swift
// 그룹 (캘린더 1개 = 그룹 1개)
struct Group {
    let calendarIdentifier: String
    var name: String
    var color: CGColor
}

// 가계부 (이벤트 제목으로 식별)
struct Ledger {
    let name: String
    var icon: String
    var color: String
    var currency: String
    var sortOrder: Int
}

// 거래 (이벤트 메모 내 파싱 단위)
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

// 스냅샷 (월별 마감 데이터)
struct MonthlySnapshot {
    let yearMonth: String       // "2026-02"
    let carryOver: Int          // 이월 잔액
    let totalIncome: Int
    let totalExpense: Int
    let closingBalance: Int     // 마감 잔액
}

// 변경 이력 (히스토리 이벤트 파싱 단위)
struct HistoryEntry {
    let date: String            // "4/01"
    let time: String            // "12:30"
    let action: HistoryAction   // .added, .modified, .deleted
    let memo: String            // "점심 김밥천국"
    let amount: String          // "-8,500원" 또는 "-45,000→-43,000원"
    let by: String              // "마스터"
}

enum HistoryAction: String {
    case added = "추가"
    case modified = "수정"
    case deleted = "삭제"
}
```

---

## 14. 카테고리 기본값

```swift
enum DefaultCategory: String, CaseIterable {
    case food = "식비"
    case transport = "교통"
    case living = "생활"
    case culture = "문화"
    case medical = "의료"
    case education = "교육"
    case clothing = "의류"
    case beauty = "미용"
    case telecom = "통신"
    case insurance = "보험"
    case salary = "급여"
    case allowance = "용돈"
    case interest = "이자"
    case other = "기타"
}
```

카테고리 목록은 UserDefaults에 저장하여 사용자가 추가/삭제/순서변경 가능.

---

## 15. 개발 페이즈

### Phase 1: 핵심 기능 (MVP)

- [ ] EventKit 권한 요청 및 캘린더 접근
- [ ] 그룹(캘린더) 생성 / 기존 캘린더 선택
- [ ] 가계부 생성 / 선택
- [ ] 거래 추가 (수동 입력)
- [ ] 거래 수정 / 삭제
- [ ] 메모 포맷 직렬화 / 파싱
- [ ] 거래 변경 히스토리 기록 (월간 히스토리 이벤트)
- [ ] 히스토리 UI (당월+전월 최신 30건)
- [ ] 달력 뷰 (월간)
- [ ] 거래 목록 뷰
- [ ] 스냅샷 자동 생성 (전전월)
- [ ] 잔액 계산 (스냅샷 + 라이브)
- [ ] 장부정리 기능

### Phase 2: 확장 기능

- [ ] 통계 차트 (월간 흐름, 카테고리 파이)
- [ ] 예산 관리
- [ ] 음성 입력 + AI 파싱
- [ ] SMS 파싱
- [ ] 가계부 메타데이터 (아이콘, 색상)
- [ ] 가계부 순서 변경

### Phase 3: 편의 기능

- [ ] iCloud 캘린더 공유 안내 가이드
- [ ] Siri / App Shortcuts 연동
- [ ] 위젯 (오늘 지출, 잔액)
- [ ] 다크모드 대응
- [ ] 검색 기능 (거래 메모 검색)

---

## 16. 앱스토어 고려사항

### 심사 통과 관련

- 캘린더를 데이터 저장소로 사용하는 것은 Apple 가이드라인 위반 사항이 아님
- 단, 캘린더 접근 사유를 명확히 설명해야 함
- 계정 생성이 없으므로 계정 삭제 요구사항 (5.1.1(v)) 해당 없음

### Info.plist 설명 문구 예시

```
NSCalendarsFullAccessUsageDescription:
"가계부 데이터를 캘린더 이벤트로 저장하고, 
공유 캘린더를 통해 다른 가족 구성원과 함께 사용합니다."
```

---

## 17. 알려진 제약사항 및 트레이드오프

| 제약 | 영향 | 수용 근거 |
|---|---|---|
| iCloud 동기화 지연 (수초~수분) | 공유 가계부 실시간성 부족 | 가정용 가계부에 실시간 필수 아님 |
| 동시 편집 시 last-write-wins | 극히 드문 데이터 유실 | 같은 초에 같은 이벤트 편집 확률 극저 |
| 캘린더 프로그래밍 공유 불가 | 앱 내 초대 코드 UX 불가 | 가이드 화면으로 iCloud 공유 안내 |
| notes 기반 쿼리 없음 | 복잡한 검색은 전체 스캔 필요 | 월 단위 조회로 충분히 빠름 |
| 변경 이력 용량 한계 | 월간 히스토리가 50KB 초과 시 분할 | 일 5건 기준 ~10KB, 실사용 문제없음 |
| EventKit 쿼리 4년 제한 | 장기 데이터 조회 시 분할 필요 | 청크 분할로 해결 |

---

## 18. 키 파일 구조 (예상)

```
Jidal-CE/
├── App/
│   ├── JidalCEApp.swift
│   ├── AppState.swift
│   └── ContentView.swift
├── Domain/
│   └── Models/
│       ├── Group.swift
│       ├── Ledger.swift
│       ├── Transaction.swift
│       ├── MonthlySnapshot.swift
│       └── HistoryEntry.swift
├── Data/
│   ├── CalendarStore.swift          ← EKEventStore 싱글톤
│   ├── GroupRepository.swift        ← 캘린더 CRUD + 선택
│   ├── LedgerRepository.swift       ← 가계부 메타 관리
│   ├── TransactionRepository.swift  ← 거래 CRUD + 메모 파싱
│   ├── SnapshotRepository.swift     ← 스냅샷 생성/조회/장부정리
│   └── HistoryRepository.swift      ← 히스토리 기록/조회/분할
├── Features/
│   ├── Onboarding/
│   │   ├── CalendarPermissionView.swift
│   │   └── GroupSetupView.swift
│   ├── Calendar/
│   │   ├── CalendarTabView.swift
│   │   └── DayDetailView.swift
│   ├── TransactionList/
│   │   ├── TransactionListView.swift
│   │   └── TransactionListViewModel.swift
│   ├── AddTransaction/
│   │   ├── AddTransactionView.swift
│   │   └── AddTransactionViewModel.swift
│   ├── Statistics/
│   │   ├── StatisticsView.swift
│   │   └── StatisticsViewModel.swift
│   ├── Settings/
│   │   ├── SettingsRootView.swift
│   │   ├── GroupManagementView.swift
│   │   ├── LedgerManagementView.swift
│   │   ├── BookClosingView.swift      ← 장부정리
│   │   └── HistoryView.swift          ← 변경 이력 (최신 30건)
│   └── Shared/
│       └── CategoryManager.swift
├── Services/
│   ├── NoteSerializer.swift         ← 거래 메모 포맷 직렬화/파싱
│   ├── HistorySerializer.swift      ← 히스토리 메모 직렬화/파싱
│   ├── BalanceCalculator.swift      ← 잔액 계산 로직
│   └── AIService.swift              ← Phase 2 음성/SMS 파싱
└── Support/
    └── Extensions.swift
```

---

## 19. 핸드오프 요약

이 정의서는 기존 Jidal(Firebase 기반)의 핵심 가계부 기능을 iOS 네이티브 캘린더만으로 재구현하기 위한 사양이다.

핵심 설계 결정:
- 캘린더 이름 = 그룹, 이벤트 제목 = 가계부, 이벤트 메모 = 당일 거래 묶음
- 메모는 사람이 읽을 수 있는 영수증 스타일 + 앱이 파싱 가능한 구조화 텍스트
- 스냅샷은 전전월까지, 전월+당월은 라이브 계산
- 장부정리로 스냅샷 수동 재생성 가능 (첫 사용일 가이드 제공)
- 월간 히스토리 이벤트로 거래 변경 이력 추적 (추가/수정/삭제)
- 히스토리 UI는 당월+전월 합산 최신 30건 표시
- 그룹 캘린더는 새로 만들기 권장, 기존 캘린더 선택도 가능 (url 스킴으로 이벤트 식별)
- 서버 없음, 로그인 없음, 캘린더 공유로 멀티유저

개발 시 가장 먼저 검증해야 할 사항:
1. EKCalendar 생성 + iCloud source 지정이 정상 동작하는지
2. 메모 포맷 직렬화/파싱 라운드트립 안정성
3. iCloud 캘린더 공유 상태에서 양방향 이벤트 수정 동기화 확인
4. 스냅샷 자동 생성 및 장부정리 정확성
5. 기존 캘린더 선택 시 url 스킴 기반 이벤트 필터링 정확성
6. 히스토리 이벤트 append 및 자동 분할 동작 확인
