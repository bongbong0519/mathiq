-- ══════════════════════════════════════════════════════════════════
--  지출 관리 시스템
--
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.expenses (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id    UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  expense_date  DATE        NOT NULL,
  category      TEXT        NOT NULL CHECK (category IN ('rent', 'materials', 'utilities', 'other')),
  amount        INTEGER     NOT NULL,
  memo          TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.expenses IS '지출 기록';
COMMENT ON COLUMN public.expenses.category IS 'rent=임대료, materials=교재비, utilities=공과금, other=기타';

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_expenses_teacher ON public.expenses(teacher_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON public.expenses(expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_expenses_category ON public.expenses(category);

-- RLS
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teacher_own_expenses" ON public.expenses;
CREATE POLICY "teacher_own_expenses"
  ON public.expenses FOR ALL
  TO authenticated
  USING (teacher_id = auth.uid())
  WITH CHECK (teacher_id = auth.uid());

DROP POLICY IF EXISTS "admin_view_expenses" ON public.expenses;
CREATE POLICY "admin_view_expenses"
  ON public.expenses FOR SELECT
  TO authenticated
  USING (public.is_admin_user());

-- updated_at 트리거
CREATE OR REPLACE FUNCTION update_expenses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_expenses_updated_at ON public.expenses;
CREATE TRIGGER trigger_expenses_updated_at
  BEFORE UPDATE ON public.expenses
  FOR EACH ROW EXECUTE FUNCTION update_expenses_updated_at();


-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- 1. 테이블 확인
-- SELECT tablename FROM pg_tables WHERE tablename = 'expenses';

-- 2. 컬럼 확인
-- SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'expenses';

-- 3. RLS 정책 확인
-- SELECT policyname FROM pg_policies WHERE tablename = 'expenses';

-- ══════════════════════════════════════════════════════════════════
