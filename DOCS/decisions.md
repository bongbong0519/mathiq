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

### 수금 상태 판정 규칙 (2026-04-24)
- `paid`: 이번 달 income에 학생 레코드 존재
- `upcoming`: 결제일까지 4일 이상 남음
- `due_soon`: 결제일까지 0~3일
- `overdue`: 결제일 지남 + 이번 달 income 없음
- `excluded`: payment_cycle NULL 또는 결제일이 이번 달 아님

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
