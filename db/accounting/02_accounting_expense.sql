-- ══════════════════════════════════════════════════════════════════════════════
-- 02_accounting_expense.sql
-- 지출(비용) 테이블 - 교습소/학원용
-- Supabase SQL Editor에서 실행 (01_accounting_income.sql 이후)
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. 테이블 생성
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.accounting_expense (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- 지출 정보
  category TEXT NOT NULL,
  amount INTEGER NOT NULL,
  expense_date DATE NOT NULL,

  -- 세금 정보
  vat_included BOOLEAN DEFAULT TRUE,          -- 부가세 포함 여부
  vat_amount INTEGER DEFAULT 0,               -- 부가세 금액

  -- 거래처 정보
  payee TEXT,                                 -- 거래처명

  -- 분류
  is_fixed BOOLEAN DEFAULT FALSE,             -- 고정비 여부
  receipt_url TEXT,                           -- 영수증 이미지 URL
  month_year TEXT,                            -- YYYY-MM (자동 계산)

  -- 기타
  memo TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- 제약조건
  CONSTRAINT accounting_expense_category_check
    CHECK (category IN ('rent', 'utility', 'material', 'equipment', 'communication', 'advertising', 'staff_salary', 'other')),
  CONSTRAINT accounting_expense_amount_positive
    CHECK (amount >= 0)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 인덱스 생성
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_accounting_expense_teacher_month
  ON public.accounting_expense(teacher_id, month_year);

CREATE INDEX IF NOT EXISTS idx_accounting_expense_teacher_date
  ON public.accounting_expense(teacher_id, expense_date);

CREATE INDEX IF NOT EXISTS idx_accounting_expense_category
  ON public.accounting_expense(teacher_id, category);

CREATE INDEX IF NOT EXISTS idx_accounting_expense_fixed
  ON public.accounting_expense(teacher_id, is_fixed)
  WHERE is_fixed = TRUE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. 트리거 함수 (expense_date 기반 month_year)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_set_month_year_from_expense()
RETURNS TRIGGER AS $$
BEGIN
  NEW.month_year = TO_CHAR(NEW.expense_date, 'YYYY-MM');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. 트리거 연결
-- ─────────────────────────────────────────────────────────────────────────────

-- updated_at (fn_set_updated_at 재사용 - 01에서 정의됨)
DROP TRIGGER IF EXISTS trg_accounting_expense_updated_at ON public.accounting_expense;
CREATE TRIGGER trg_accounting_expense_updated_at
  BEFORE UPDATE ON public.accounting_expense
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_accounting_expense_month_year ON public.accounting_expense;
CREATE TRIGGER trg_accounting_expense_month_year
  BEFORE INSERT OR UPDATE ON public.accounting_expense
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_month_year_from_expense();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RLS 활성화 및 정책
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.accounting_expense ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "expense_select_own" ON public.accounting_expense;
CREATE POLICY "expense_select_own" ON public.accounting_expense
  FOR SELECT USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS "expense_insert_own" ON public.accounting_expense;
CREATE POLICY "expense_insert_own" ON public.accounting_expense
  FOR INSERT WITH CHECK (teacher_id = auth.uid());

DROP POLICY IF EXISTS "expense_update_own" ON public.accounting_expense;
CREATE POLICY "expense_update_own" ON public.accounting_expense
  FOR UPDATE USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS "expense_delete_own" ON public.accounting_expense;
CREATE POLICY "expense_delete_own" ON public.accounting_expense
  FOR DELETE USING (teacher_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. 컬럼 코멘트
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON TABLE public.accounting_expense IS '지출(비용) 테이블 - 교습소/학원용';
COMMENT ON COLUMN public.accounting_expense.category IS '지출 카테고리: rent(임대료), utility(공과금), material(교재/자료), equipment(장비), communication(통신비), advertising(광고비), staff_salary(인건비), other(기타)';
COMMENT ON COLUMN public.accounting_expense.vat_included IS '부가세 포함 여부';
COMMENT ON COLUMN public.accounting_expense.vat_amount IS '부가세 금액';
COMMENT ON COLUMN public.accounting_expense.is_fixed IS '고정비 여부 (매월 반복)';
COMMENT ON COLUMN public.accounting_expense.month_year IS '귀속 월 (YYYY-MM, 자동 계산)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  'accounting_expense' AS table_name,
  COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'accounting_expense';

SELECT
  indexname,
  indexdef
FROM pg_indexes
WHERE tablename = 'accounting_expense';

SELECT
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'accounting_expense';
