-- ══════════════════════════════════════════════════════════════════════════════
-- 01_accounting_income.sql
-- 수입(매출) 테이블
-- Supabase SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. 테이블 생성
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.accounting_income (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- 학생 정보
  student_name TEXT NOT NULL,
  student_id UUID REFERENCES public.students(id) ON DELETE SET NULL,

  -- 금액 정보
  amount INTEGER NOT NULL,                    -- 최종 결제 금액
  base_amount INTEGER,                        -- 기본 수업료
  discount_amount INTEGER DEFAULT 0,          -- 할인 금액
  material_fee INTEGER DEFAULT 0,             -- 교재비

  -- 결제 정보
  payment_date DATE NOT NULL,
  payment_method TEXT NOT NULL DEFAULT 'transfer',
  cash_receipt_issued BOOLEAN DEFAULT FALSE,
  cash_receipt_number TEXT,

  -- 분류 정보
  month_year TEXT,                            -- YYYY-MM (자동 계산)
  class_id UUID,                              -- 수업 ID (추후 연결)
  class_name TEXT,                            -- 수업명

  -- 기타
  memo TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- 제약조건
  CONSTRAINT accounting_income_payment_method_check
    CHECK (payment_method IN ('cash', 'transfer', 'card', 'pg', 'other')),
  CONSTRAINT accounting_income_amount_positive
    CHECK (amount >= 0)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 인덱스 생성
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_accounting_income_teacher_month
  ON public.accounting_income(teacher_id, month_year);

CREATE INDEX IF NOT EXISTS idx_accounting_income_teacher_date
  ON public.accounting_income(teacher_id, payment_date);

CREATE INDEX IF NOT EXISTS idx_accounting_income_student
  ON public.accounting_income(student_id);

CREATE INDEX IF NOT EXISTS idx_accounting_income_cash_receipt
  ON public.accounting_income(teacher_id, payment_method, cash_receipt_issued)
  WHERE payment_method = 'cash' AND cash_receipt_issued = FALSE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. 트리거 함수 (공통 재사용)
-- ─────────────────────────────────────────────────────────────────────────────

-- updated_at 자동 갱신 함수
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- month_year 자동 계산 함수 (payment_date 기반)
CREATE OR REPLACE FUNCTION public.fn_set_month_year_from_payment()
RETURNS TRIGGER AS $$
BEGIN
  NEW.month_year = TO_CHAR(NEW.payment_date, 'YYYY-MM');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. 트리거 연결
-- ─────────────────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_accounting_income_updated_at ON public.accounting_income;
CREATE TRIGGER trg_accounting_income_updated_at
  BEFORE UPDATE ON public.accounting_income
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_accounting_income_month_year ON public.accounting_income;
CREATE TRIGGER trg_accounting_income_month_year
  BEFORE INSERT OR UPDATE ON public.accounting_income
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_month_year_from_payment();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RLS 활성화 및 정책
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.accounting_income ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "income_select_own" ON public.accounting_income;
CREATE POLICY "income_select_own" ON public.accounting_income
  FOR SELECT USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS "income_insert_own" ON public.accounting_income;
CREATE POLICY "income_insert_own" ON public.accounting_income
  FOR INSERT WITH CHECK (teacher_id = auth.uid());

DROP POLICY IF EXISTS "income_update_own" ON public.accounting_income;
CREATE POLICY "income_update_own" ON public.accounting_income
  FOR UPDATE USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS "income_delete_own" ON public.accounting_income;
CREATE POLICY "income_delete_own" ON public.accounting_income
  FOR DELETE USING (teacher_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. 컬럼 코멘트
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON TABLE public.accounting_income IS '수입(매출) 테이블 - 수업료 결제 내역';
COMMENT ON COLUMN public.accounting_income.amount IS '최종 결제 금액 (원)';
COMMENT ON COLUMN public.accounting_income.base_amount IS '기본 수업료';
COMMENT ON COLUMN public.accounting_income.discount_amount IS '할인 금액 (형제할인 등)';
COMMENT ON COLUMN public.accounting_income.material_fee IS '교재비';
COMMENT ON COLUMN public.accounting_income.payment_method IS '결제수단: cash(현금), transfer(계좌이체), card(카드), pg(PG결제), other(기타)';
COMMENT ON COLUMN public.accounting_income.cash_receipt_issued IS '현금영수증 발급 여부';
COMMENT ON COLUMN public.accounting_income.month_year IS '귀속 월 (YYYY-MM, 자동 계산)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  'accounting_income' AS table_name,
  COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'accounting_income';

SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'accounting_income';

SELECT
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'accounting_income';
