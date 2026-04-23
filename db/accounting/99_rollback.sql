-- ══════════════════════════════════════════════════════════════════════════════
-- 99_rollback.sql
-- 회계 시스템 전체 롤백 (되돌리기)
-- 주의: 모든 회계 데이터가 삭제됩니다!
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. 뷰 삭제 (의존성 순서: 하위 → 상위)
-- ─────────────────────────────────────────────────────────────────────────────

DROP VIEW IF EXISTS public.v_yearly_summary CASCADE;
DROP VIEW IF EXISTS public.v_monthly_pnl CASCADE;
DROP VIEW IF EXISTS public.v_monthly_salary CASCADE;
DROP VIEW IF EXISTS public.v_monthly_expense CASCADE;
DROP VIEW IF EXISTS public.v_monthly_income CASCADE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 테이블 삭제 (의존성 순서: FK 참조 → 마스터)
-- ─────────────────────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS public.accounting_staff_salary CASCADE;
DROP TABLE IF EXISTS public.academy_staff CASCADE;
DROP TABLE IF EXISTS public.accounting_settings CASCADE;
DROP TABLE IF EXISTS public.accounting_expense CASCADE;
DROP TABLE IF EXISTS public.accounting_income CASCADE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. 트리거 함수 삭제
-- ─────────────────────────────────────────────────────────────────────────────

DROP FUNCTION IF EXISTS public.fn_set_updated_at() CASCADE;
DROP FUNCTION IF EXISTS public.fn_set_month_year_from_payment() CASCADE;
DROP FUNCTION IF EXISTS public.fn_set_month_year_from_expense() CASCADE;
DROP FUNCTION IF EXISTS public.fn_ensure_accounting_settings() CASCADE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. profiles 테이블 컬럼/제약조건 삭제
-- ─────────────────────────────────────────────────────────────────────────────

-- 제약조건 삭제
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_business_type_check;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_business_status_check;

-- 컬럼 삭제
ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS business_type;

ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS business_status;

ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS business_start_date;

ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS cash_receipt_enabled;

-- ─────────────────────────────────────────────────────────────────────────────
-- 검증 쿼리 (삭제 확인)
-- ─────────────────────────────────────────────────────────────────────────────

-- 테이블 확인
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'accounting_income',
    'accounting_expense',
    'accounting_settings',
    'academy_staff',
    'accounting_staff_salary'
  );
-- 결과가 0행이면 성공

-- 뷰 확인
SELECT table_name
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name LIKE 'v_%';
-- v_monthly_*, v_yearly_* 가 없으면 성공

-- profiles 컬럼 확인
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'profiles'
  AND column_name IN ('business_type', 'business_status', 'business_start_date', 'cash_receipt_enabled');
-- 결과가 0행이면 성공
