# MathIQ 결정 로그 (Decisions)

> 이 파일은 프로젝트의 **되돌리면 안 되는 설계 결정들**을 기록한다.
> 새 채팅/세션에서 Claude가 임의로 재설계하는 것을 방지하는 목적.
> 새 결정이 생기면 맨 아래에 날짜 순으로 추가. 기존 결정은 함부로 수정 금지.

## 🔒 검증 완료 / 수정 금지 함수

다음 함수들은 실제 테스트 통과 후 확정됨. 재설계·리네이밍 금지:

- `getNextPaymentDate(student, today)` — 월/격주/특정일 주기별 다음 결제일 반환
- `getDaysUntilPayment(paymentDate, today)` — D-day까지 남은 일수 반환
- `getDdayText(days)` — 관례: `D-N`=앞으로 N일 / `D+N`=N일 연체 / `D-day`=당일
- `getLocalDateStr(date)` — 로컬 타임존 기반 `YYYY-MM-DD` (toISOString 쓰지 말 것)
- `renderUpcomingPayments()` — paid 판정은 `nextDate가 속한 달`의 income으로만
- `getPaymentStatus(student, thisMonthIncome, today)` — 수금 상태 판정 (paid/upcoming/due_soon/overdue)
- `getThisMonthPaymentDate(student, today)` — 이번 달 결제일 반환 (monthly 전용)
- `renderPaymentCollectionStatus()` — 이번 달 수금 현황 섹션 렌더
- `loadMonthlyTrend(months)` — 월별 수입/지출/순이익 집계 (accounting_income + accounting_expense GROUP BY month_year)
- `renderMonthlyTrendChart(data)` — Chart.js 혼합 차트(막대+선) 렌더
- `getCalendarMatrix(year, month)` — 6주(42칸) 캘린더 매트릭스 생성
- `loadCalendarEvents(year, month)` — 해당 월의 캘린더 이벤트 로드
- `renderCalendar()` — 캘린더 전체 렌더링 (그리드 + 사이드바 + 상세패널)
- `renderCalendarGrid()` — 캘린더 날짜 그리드 렌더
- `renderCalendarSidebar()` — 이번 달 일정 목록 렌더
- `renderDayDetail(dateStr)` — 선택 날짜 상세 패널 렌더
- `selectCalendarDay(dateStr)` — 날짜 선택 및 상태 업데이트
- `navigateMonth(direction)` — 이전달(-1)/다음달(1)/오늘('today') 이동
- `saveCalendarEvent()` — 일정 추가/수정 저장
- `deleteCalendarEvent()` — 일정 삭제

> **2026-04-24 버그 수정**: getNextPaymentDate는 "다음" 결제일을 반환하므로 결제일 지난 학생이 다음 달로 넘어감.
> 수금 현황에서는 getThisMonthPaymentDate로 "이번 달" 결제일을 계산하도록 수정.

## 📐 스키마 결정

### students 결제 관련 (2026-04-24)
- `payment_cycle VARCHAR(20)` — `monthly` | `biweekly` | `custom` | NULL
- `payment_day INTEGER` — 1~31 (monthly일 때만 사용)
- `payment_start_date DATE` — biweekly/custom 용
- `payment_notify_d3 / dday / d1_overdue BOOLEAN` — 알림 플래그 (기본 TRUE)

### accounting_income 카테고리 (2026-04-24)
- `category VARCHAR(30) DEFAULT '정규수강료'`
- 허용값: `정규수강료` / `보충수업` / `교재비` / `특강` / `기타`

### accounting_expense 테이블 (2026-04-24)
- 카테고리 고정값: `임대료` / `관리비` / `교재구입` / `사무용품` / `식비` / `교통비` / `광고비` / `통신비` / `기타`
- `payment_method`: `transfer` / `cash` / `card`
- `month_year`: `expense_date` 기준 자동 계산 (트리거)
- RLS: `teachers_own_rows` 4종 (select/insert/update/delete)

### calendar_events 테이블 (2026-04-24)
- 대시보드 월간 캘린더용 개인 일정
- `event_type VARCHAR(20)` — `시험` / `상담` / `수업` / `휴일` / `기타`
- `color VARCHAR(20)` — 이벤트 색상 HEX (기본 #F59E0B)
- RLS: `teachers_own_calendar_*` 4종 (select/insert/update/delete)
- 기본 색상: 시험=#EF4444, 상담=#8B5CF6, 수업=#3B82F6, 휴일=#6B7280, 기타=#F59E0B
- **1차 범위**: 개인 일정 CRUD만. 결제일 자동 표시/school_events/공휴일 API는 2차.

### 수금 상태 판정 규칙 (2026-04-24)
- `paid`: 이번 달 income에 학생 레코드 존재
- `upcoming`: 결제일까지 4일 이상 남음
- `due_soon`: 결제일까지 0~3일
- `overdue`: 결제일 지남 + 이번 달 income 없음
- `excluded`: payment_cycle NULL 또는 결제일이 이번 달 아님

### 향후 예정: school_events (학교 공용 일정)

- 2차 기능 예정 (2026-04-24 봉쌤 아이디어)
- 학교별 시험기간·방학·학사일정을 선생이 등록해서 같은 학교 학생·선생에게 자동 공유
- 캘린더에만 연동 (학부모 알림 제외)

**등록 권한: 선생님만**
- 학생 입력은 오류 리스크로 제외 (잘못 입력 시 학교 전체 피해)
- 학생 → 선생 보고 플로우로 운영
- 학생은 자기 학교/학년 매칭되는 이벤트 자동 수신 (읽기 전용)
- 신뢰 체계 불필요 (선생 등록 = 기본 신뢰)

**카테고리 (3그룹 체계):**

| 카테고리 | 포함 | 기본 색상 |
|---------|------|----------|
| 시험 | 중간고사, 기말고사, 수행평가, 교육청 모의고사, 사설 모의고사 | #EF4444 (빨강) |
| 휴일 | 방학, 개교기념일, 재량휴업일, 개학식, 종업식, 졸업식 | #6B7280 (회색) |
| 학교행사 | 체육대회/수학여행 등 (2차 확장, 우선순위 낮음) | #3B82F6 (파랑) |

**공휴일 자동 표시:**
- 공공데이터포털 "특일 정보" API 사용 (https://www.data.go.kr)
- 연 단위 미리 캐싱 후 캘린더에 기본 표시
- school_events와 별개 소스
- 대체공휴일/임시공휴일 자동 반영 가능

**예정 테이블 스키마:**

```sql
school_events (
  id UUID PRIMARY KEY,
  school_name VARCHAR,
  event_type VARCHAR CHECK (IN ('중간고사','기말고사','수행평가','교육청모의고사','사설모의고사','방학','개교기념일','재량휴업','개학','종업','졸업','체육대회','수학여행','기타행사')),
  start_date DATE,
  end_date DATE,  -- 기간 이벤트 지원 (시험기간, 방학 등)
  target_grade INTEGER,  -- 1/2/3, NULL이면 전학년
  semester VARCHAR,  -- '1학기','2학기', NULL이면 무관
  submitted_by UUID REFERENCES auth.users(id),
  memo TEXT,
  created_at, updated_at
)
```

**주의:**
- school_name은 추후 NEIS 학교코드 연동 시 school_id로 업그레이드 예정
- 사설 모의고사(이투스/시대인재/메가스터디 등) 포함 — 교육청 모의고사와 별도 타입
- 개교기념일은 학교마다 달라서 크라우드소싱 필수 항목
- 공휴일은 school_events에 넣지 말 것 (API로 별도 처리)

## 💰 세액 계산 규칙 (2026-04-24)

신고 구분별 계산 로직:
- **프리랜서**: 총수입 × 3.3% (필요경비 0)
- **사업소득**: 단순경비율 적용 후 누진세율 (교습소/과외 61.7%, 학원 55%)
- **기타소득**: 필요경비 60% 인정 후 22% (소득세 20% + 지방세 2%)

누진세율표 기준: 2024년 (1,400만/5천만/8,800만/1.5억/3억/5억/10억 구간)

> **2026-04-24 구현 완료**: `calculateTax(totalIncome, reportType, businessType)` 함수로 분리.
> 하위 함수: `calculateTaxFreelancer`, `calculateTaxBusiness`, `calculateTaxOther`, `calculateProgressiveTax`

## 🧭 관례 / 컨벤션

- **모든 쿼리는 teacher_id 필터 필수** (RLS 우회 루트 만들지 말 것)
- **날짜 문자열은 `getLocalDateStr()`** — `toISOString().slice(0,10)` 사용 금지 (KST off-by-one 버그)
- **돈은 원 단위 정수**, `Math.round()` 반올림
- **파이포인트 ≠ 파이캐쉬** — 포인트는 비환급, 캐쉬는 환급 가능
- **구독 티어**: `campus`(무료) / `basic` / `standard` / `premium` / `pro`
- **OPEN_EVENT 플래그는 자료실 포인트 보너스에만 영향** — 티어 기능제한은 항상 유효

### Chart.js 인스턴스 관리 (2026-04-24)
- 전역 변수 패턴: `_chartName` (예: `_monthlyTrendChart`)
- 재렌더링 시 `destroy()` 먼저 호출 후 새 인스턴스 생성
- 기존 차트: `_accIncomePieChart`, `_accExpensePieChart`, `_monthlyTrendChart`

## 🏛 비즈니스 모델 고정값

- 수익원: 구독 + 파이포인트 충전만
- 과외 중개 수수료 모델: **폐기**
- 과외 프로필 연락처 조회: 500pt (연결만, 중개 아님)
- 교사·학부모 공간 분리: **의도적 설계**. 통합 요청 와도 유지

## ⚠️ 새 세션 시작 체크리스트

1. 이 파일 먼저 읽기
2. `🔒 검증 완료` 섹션 함수는 로직 재설계 금지
3. 스키마 변경이 필요하면 사용자에게 먼저 제안 → 승인 후 진행
4. 기존 컨벤션과 다른 패턴 도입 금지 (예: 새로운 날짜 유틸 추가 등)
