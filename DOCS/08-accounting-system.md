# 회계 시스템 설계

> **문서 상태**: 설계 완료, 구현 예정  
> **작성일**: 2026-04-21  
> **구현 목표**: Phase 1 (6개월 이후)

---

## 1. 목적

선생님/원장이 학부모에게 수강료 관련 문자를 자동화.  
회계 데이터가 학부모 문자 시스템([02-parent-sms.md](./02-parent-sms.md))의 데이터 소스 역할.

### 봉쌤 통찰
> "선생님/원장이 학부모한테 문자 편하게 보내려면 회계 시스템 필수"

---

## 2. 핵심 기능

### 2.1 수강료 관리

| 기능 | 설명 |
|------|------|
| 학생별 월 수강료 등록 | 학생마다 다른 금액 설정 가능 |
| 납부 상태 관리 | 완납 / 부분납 / 미납 |
| 청구일 설정 | 매월 며칠에 청구할지 (예: 매월 1일) |
| 자동 청구 알림 | 청구일에 학부모 문자 자동 발송 |

### 2.2 자동 문자 발송 (학부모 문자 시스템 연계)

기존 학부모 문자 유형 (02-parent-sms.md):
- 성적 안내
- 출결 안내
- 숙제 안내
- 자유 메시지

**추가 유형:**

| 시점 | 메시지 유형 | 예시 |
|------|------------|------|
| 월초 (청구일) | 수강료 청구 | "4월 수강료 30만원 안내드립니다" |
| 납부 완료 시 | 납부 확인 | "4월 수강료 납부 확인되었습니다" |
| 미납 5일 전 | 납부 안내 | "4월 수강료 납부일이 5일 남았습니다" |
| 미납 시 | 미납 안내 | "4월 수강료가 미납 상태입니다" |

### 2.3 영수증 발행

| 단계 | 기능 |
|------|------|
| Phase 1 | 수동 PDF 영수증 생성 |
| Phase 2 | 자동 PDF 영수증 (납부 시 자동 생성) |
| Phase 3 | 현금영수증 (사업자등록 후) |

- 학부모 이메일/문자로 자동 전달
- PDF 다운로드 가능

### 2.4 학원 매출 관리 (원장 전용)

| 기능 | 설명 |
|------|------|
| 월 매출 그래프 | 월별 수강료 수입 추이 |
| 학생별 수익 | 학생 1인당 월 수익 |
| 강사별 수익 | 강사가 담당한 학생 총수익 |
| 손익 계산 | 매출 - 강사료 - 운영비 |

### 2.5 강사료 정산

| 기능 | 설명 |
|------|------|
| 강사별 수업료 단가 | 학생 1명당 강사 몫 설정 |
| 자동 계산 | 학생 수 × 단가 |
| 정산 일정 | 매월 말 또는 지정일 자동 알림 |

---

## 3. 기술 구현 스케치

### 테이블 설계 (초안)

```sql
-- 수강료 마스터 (학생별 월 수강료 설정)
CREATE TABLE tuitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,
  organization_id UUID REFERENCES organizations(id),
  teacher_id UUID REFERENCES profiles(id),
  
  monthly_fee INTEGER NOT NULL,        -- 월 수강료 (원)
  billing_day INTEGER DEFAULT 1,       -- 매월 며칠 청구 (1~28)
  
  start_date DATE NOT NULL,            -- 수강 시작일
  end_date DATE,                       -- 수강 종료일 (null = 진행중)
  status TEXT DEFAULT 'active',        -- active/paused/ended
  
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 납부 이력
CREATE TABLE tuition_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tuition_id UUID REFERENCES tuitions(id) ON DELETE CASCADE,
  
  amount_paid INTEGER NOT NULL,        -- 납부 금액
  paid_at TIMESTAMPTZ DEFAULT now(),   -- 납부 시점
  payment_method TEXT,                 -- cash/transfer/card
  status TEXT DEFAULT 'paid',          -- paid/partial/refunded
  
  note TEXT,                           -- 메모
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 청구서 (매월 자동 생성)
CREATE TABLE tuition_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tuition_id UUID REFERENCES tuitions(id) ON DELETE CASCADE,
  
  billing_period TEXT NOT NULL,        -- '2026-04'
  amount_due INTEGER NOT NULL,         -- 청구 금액
  due_date DATE NOT NULL,              -- 납부 기한
  
  sent_at TIMESTAMPTZ,                 -- 문자 발송 시점
  paid_at TIMESTAMPTZ,                 -- 완납 시점
  status TEXT DEFAULT 'pending',       -- pending/sent/paid/overdue
  
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 강사 정산
CREATE TABLE teacher_settlements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID REFERENCES profiles(id),
  organization_id UUID REFERENCES organizations(id),
  
  period TEXT NOT NULL,                -- '2026-04'
  student_count INTEGER,               -- 담당 학생 수
  total_amount INTEGER,                -- 정산 금액
  
  settled_at TIMESTAMPTZ,              -- 정산 완료 시점
  status TEXT DEFAULT 'pending',       -- pending/settled
  
  created_at TIMESTAMPTZ DEFAULT now()
);
```

---

## 4. 구현 단계

### Phase 1 (기본) - 6개월 후

- [ ] 수강료 수동 입력 (학생별)
- [ ] 납부 체크 (수동 입력)
- [ ] 수동 문자 발송 (학부모 SMS UI 활용)
- [ ] 간단한 월 매출 조회

**운영 방식:**
- 선생님이 직접 수강료/납부 입력
- 문자는 기존 학부모 SMS 기능으로 수동 발송

---

### Phase 2 (자동화) - 1년 후

- [ ] 매월 자동 청구서 생성 (billing_day 기준)
- [ ] 자동 문자 발송 (청구/미납 알림)
- [ ] 영수증 자동 PDF 생성
- [ ] 미납 자동 알림 (D-5, D-day)

---

### Phase 3 (결제 연동) - 사업자등록 후

- [ ] 토스페이먼츠 / 카카오페이 연동
- [ ] 자동 결제 (학부모 카드 등록)
- [ ] 현금영수증 자동 발행
- [ ] 결제 실패 자동 재시도

---

### Phase 4 (정산 자동화) - 장기

- [ ] 강사료 자동 계산 (학생 수 × 단가)
- [ ] 정산 자동화 (매월 말)
- [ ] 세무 연동 (홈택스 API, 가능 시)
- [ ] 연간 손익 리포트

---

## 5. 학부모 문자 시스템 연계

### 현재 (02-parent-sms.md)

```
메시지 유형: 성적 | 출결 | 숙제 | 자유
```

### 회계 연계 후

```
메시지 유형: 성적 | 출결 | 숙제 | 자유 | 수강료 | 납부확인 | 미납안내
```

### 데이터 흐름

```
tuitions (수강료 설정)
    ↓
tuition_invoices (매월 청구서 생성)
    ↓
학부모 문자 시스템 (자동 발송)
    ↓
tuition_payments (납부 확인)
    ↓
학부모 문자 시스템 (납부 확인 발송)
```

---

## 6. 역할별 기능

| 기능 | 선생님 | 원장 | 학부모 | 운영자 |
|------|:------:|:----:|:------:|:------:|
| 학생 수강료 설정 | ✅ | ✅ | ❌ | ✅ |
| 납부 입력 | ✅ | ✅ | ❌ | ✅ |
| 납부 내역 조회 | ✅ (담당) | ✅ (전체) | ✅ (본인) | ✅ |
| 청구서 발송 | ✅ | ✅ | ❌ | ✅ |
| 매출 통계 | ✅ (담당) | ✅ (전체) | ❌ | ✅ |
| 강사 정산 | ❌ | ✅ | ❌ | ✅ |

---

## 7. 미해결 고민

### 정책 관련

| 질문 | 현재 생각 |
|------|----------|
| 부분납 처리? | 남은 금액 다음달 이월? 별도 청구? |
| 환불 정책? | 중도 환불 시 계산 방식? |
| 형제 할인? | 둘째 10% 할인 등 자동 적용? |
| 장기 결석 시? | 감면? 그대로? 휴원 처리? |
| 강사 변경 시? | 수익 분배 어떻게? |
| 휴원 처리? | 수강료 일시 중단 기능 필요? |

### 기술 관련

| 질문 | 현재 생각 |
|------|----------|
| 결제 PG사? | 토스페이먼츠 vs 카카오페이 |
| 현금영수증 API? | 국세청 연동 필요 |
| 세금계산서? | 사업자 대 사업자 거래 시 |

---

## 8. 확정 사항 (2026-04-21)

봉쌤 결정:

| 항목 | 결정 |
|------|------|
| 학부모 문자 연계 | 필수 (회계 = 문자 데이터 소스) |
| Phase 1 범위 | 수동 입력 + 수동 문자 |
| 결제 연동 시점 | 사업자등록 이후 |
| 정산 대상 | 원장 → 강사 (학원 모델) |

---

## 변경 이력

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-04-21 | 초안 작성 | 봉쌤 + Claude |
