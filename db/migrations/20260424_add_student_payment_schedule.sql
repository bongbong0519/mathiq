-- ══════════════════════════════════════════════════════════════════════════════
-- 20260424_add_student_payment_schedule.sql
-- 학생 결제 주기/알림 관리 컬럼 추가
-- Supabase SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. students 테이블에 결제 관련 컬럼 추가
-- ─────────────────────────────────────────────────────────────────────────────

-- 결제 주기 (monthly: 매달, biweekly: 격주, custom: 특정일 1회)
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS payment_cycle TEXT
  CHECK (payment_cycle IS NULL OR payment_cycle IN ('monthly', 'biweekly', 'custom'));

-- 결제일 (매달 며칠, 1-31)
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS payment_day INTEGER
  CHECK (payment_day IS NULL OR (payment_day >= 1 AND payment_day <= 31));

-- 첫 결제일/기준일 (biweekly/custom에서 사용)
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS payment_start_date DATE;

-- 알림 설정 (기본값 true)
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS payment_notify_d3 BOOLEAN DEFAULT true;

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS payment_notify_dday BOOLEAN DEFAULT true;

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS payment_notify_d1_overdue BOOLEAN DEFAULT true;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 컬럼 코멘트
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON COLUMN public.students.payment_cycle IS '결제 주기: monthly(매달), biweekly(격주), custom(특정일 1회)';
COMMENT ON COLUMN public.students.payment_day IS '매달 결제일 (1-31), payment_cycle=monthly일 때 사용';
COMMENT ON COLUMN public.students.payment_start_date IS '첫 결제일/기준일, biweekly/custom에서 사용';
COMMENT ON COLUMN public.students.payment_notify_d3 IS 'D-3 미리 알림 여부';
COMMENT ON COLUMN public.students.payment_notify_dday IS 'D-day 당일 알림 여부';
COMMENT ON COLUMN public.students.payment_notify_d1_overdue IS 'D+1 연체 경고 여부';

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'students'
  AND column_name IN (
    'payment_cycle',
    'payment_day',
    'payment_start_date',
    'payment_notify_d3',
    'payment_notify_dday',
    'payment_notify_d1_overdue'
  )
ORDER BY ordinal_position;
-- 6개 행이 나오면 성공
