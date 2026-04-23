-- ══════════════════════════════════════════════════════════════════════════════
-- 03_accounting_staff_salary.sql
-- 강사/직원 관리 및 급여 테이블 - 학원 전용
-- Supabase SQL Editor에서 실행 (01_accounting_income.sql 이후)
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. 강사 마스터 테이블
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.academy_staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- 기본 정보
  staff_name TEXT NOT NULL,
  staff_role TEXT DEFAULT 'teacher',          -- teacher(강사), admin(행정), other(기타)

  -- 급여 정보
  salary_type TEXT NOT NULL DEFAULT 'hourly',
  base_rate INTEGER NOT NULL DEFAULT 0,       -- 기본 단가 (월급/시급/커미션 기준)

  -- 고용 정보
  employment_type TEXT DEFAULT 'part_time',
  is_active BOOLEAN DEFAULT TRUE,
  hire_date DATE,

  -- 세금/보험
  withholding_rate NUMERIC(4,2) DEFAULT 3.3,  -- 원천징수율 (%)
  has_four_insurance BOOLEAN DEFAULT FALSE,    -- 4대보험 가입 여부

  -- 기타
  memo TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- 제약조건
  CONSTRAINT academy_staff_salary_type_check
    CHECK (salary_type IN ('monthly', 'hourly', 'commission')),
  CONSTRAINT academy_staff_employment_type_check
    CHECK (employment_type IN ('regular', 'part_time', 'freelancer')),
  CONSTRAINT academy_staff_role_check
    CHECK (staff_role IN ('teacher', 'admin', 'other'))
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 월별 급여 테이블
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.accounting_staff_salary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES public.academy_staff(id) ON DELETE CASCADE,

  -- 기간
  month_year TEXT NOT NULL,                   -- YYYY-MM

  -- 근무 정보
  hours_worked NUMERIC(6,2) DEFAULT 0,        -- 근무 시간
  hourly_rate INTEGER DEFAULT 0,              -- 적용 시급

  -- 커미션 정보
  commission_base INTEGER DEFAULT 0,          -- 커미션 기준 금액 (수입 등)
  commission_rate NUMERIC(5,2) DEFAULT 0,     -- 커미션율 (%)

  -- 급여 계산
  gross_amount INTEGER NOT NULL DEFAULT 0,    -- 총 급여
  withholding_tax INTEGER DEFAULT 0,          -- 원천징수액
  four_insurance_amount INTEGER DEFAULT 0,    -- 4대보험 공제
  other_deduction INTEGER DEFAULT 0,          -- 기타 공제
  net_amount INTEGER NOT NULL DEFAULT 0,      -- 실수령액

  -- 지급 정보
  payment_date DATE,
  payment_status TEXT DEFAULT 'pending',

  -- 기타
  memo TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- 제약조건
  CONSTRAINT accounting_staff_salary_unique_month
    UNIQUE (staff_id, month_year),
  CONSTRAINT accounting_staff_salary_status_check
    CHECK (payment_status IN ('pending', 'paid', 'cancelled'))
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. 인덱스 생성
-- ─────────────────────────────────────────────────────────────────────────────

-- academy_staff
CREATE INDEX IF NOT EXISTS idx_academy_staff_owner
  ON public.academy_staff(owner_id);

CREATE INDEX IF NOT EXISTS idx_academy_staff_active
  ON public.academy_staff(owner_id, is_active)
  WHERE is_active = TRUE;

-- accounting_staff_salary
CREATE INDEX IF NOT EXISTS idx_staff_salary_owner_month
  ON public.accounting_staff_salary(owner_id, month_year);

CREATE INDEX IF NOT EXISTS idx_staff_salary_staff
  ON public.accounting_staff_salary(staff_id);

CREATE INDEX IF NOT EXISTS idx_staff_salary_status
  ON public.accounting_staff_salary(owner_id, payment_status)
  WHERE payment_status = 'pending';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. 트리거 연결
-- ─────────────────────────────────────────────────────────────────────────────

-- academy_staff updated_at
DROP TRIGGER IF EXISTS trg_academy_staff_updated_at ON public.academy_staff;
CREATE TRIGGER trg_academy_staff_updated_at
  BEFORE UPDATE ON public.academy_staff
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- accounting_staff_salary updated_at
DROP TRIGGER IF EXISTS trg_staff_salary_updated_at ON public.accounting_staff_salary;
CREATE TRIGGER trg_staff_salary_updated_at
  BEFORE UPDATE ON public.accounting_staff_salary
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RLS 활성화 및 정책
-- ─────────────────────────────────────────────────────────────────────────────

-- academy_staff
ALTER TABLE public.academy_staff ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "staff_select_own" ON public.academy_staff;
CREATE POLICY "staff_select_own" ON public.academy_staff
  FOR SELECT USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "staff_insert_own" ON public.academy_staff;
CREATE POLICY "staff_insert_own" ON public.academy_staff
  FOR INSERT WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "staff_update_own" ON public.academy_staff;
CREATE POLICY "staff_update_own" ON public.academy_staff
  FOR UPDATE USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "staff_delete_own" ON public.academy_staff;
CREATE POLICY "staff_delete_own" ON public.academy_staff
  FOR DELETE USING (owner_id = auth.uid());

-- accounting_staff_salary
ALTER TABLE public.accounting_staff_salary ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "salary_select_own" ON public.accounting_staff_salary;
CREATE POLICY "salary_select_own" ON public.accounting_staff_salary
  FOR SELECT USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "salary_insert_own" ON public.accounting_staff_salary;
CREATE POLICY "salary_insert_own" ON public.accounting_staff_salary
  FOR INSERT WITH CHECK (owner_id = auth.uid());

DROP POLICY IF EXISTS "salary_update_own" ON public.accounting_staff_salary;
CREATE POLICY "salary_update_own" ON public.accounting_staff_salary
  FOR UPDATE USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "salary_delete_own" ON public.accounting_staff_salary;
CREATE POLICY "salary_delete_own" ON public.accounting_staff_salary
  FOR DELETE USING (owner_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. 컬럼 코멘트
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON TABLE public.academy_staff IS '강사/직원 마스터 테이블 - 학원 전용';
COMMENT ON COLUMN public.academy_staff.salary_type IS '급여 유형: monthly(월급), hourly(시급), commission(커미션)';
COMMENT ON COLUMN public.academy_staff.employment_type IS '고용 형태: regular(정규직), part_time(시간제), freelancer(프리랜서)';
COMMENT ON COLUMN public.academy_staff.withholding_rate IS '원천징수율 (%, 기본 3.3%)';
COMMENT ON COLUMN public.academy_staff.has_four_insurance IS '4대보험 가입 여부';

COMMENT ON TABLE public.accounting_staff_salary IS '월별 급여 내역 테이블';
COMMENT ON COLUMN public.accounting_staff_salary.gross_amount IS '총 급여 (세전)';
COMMENT ON COLUMN public.accounting_staff_salary.withholding_tax IS '원천징수액';
COMMENT ON COLUMN public.accounting_staff_salary.net_amount IS '실수령액';
COMMENT ON COLUMN public.accounting_staff_salary.payment_status IS '지급 상태: pending(대기), paid(지급완료), cancelled(취소)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  table_name,
  COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('academy_staff', 'accounting_staff_salary')
GROUP BY table_name;

SELECT
  tablename,
  policyname,
  cmd
FROM pg_policies
WHERE tablename IN ('academy_staff', 'accounting_staff_salary')
ORDER BY tablename, policyname;
