-- ══════════════════════════════════════════════════════════════════════════════
-- 00_extend_profiles.sql
-- profiles 테이블 확장: 사업자 정보 컬럼 추가
-- Supabase SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. 컬럼 추가 (IF NOT EXISTS 방식)
-- ─────────────────────────────────────────────────────────────────────────────

-- business_type: 업태 (과외/교습소/학원)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS business_type TEXT;

-- business_status: 사업자 상태
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS business_status TEXT;

-- business_start_date: 사업 시작일
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS business_start_date DATE;

-- cash_receipt_enabled: 현금영수증 발급 가능 여부
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS cash_receipt_enabled BOOLEAN DEFAULT FALSE;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. CHECK 제약조건 추가 (중복 방지)
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  -- business_type 제약조건
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_business_type_check'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_business_type_check
      CHECK (business_type IS NULL OR business_type IN ('tutoring', 'institute', 'academy'));
  END IF;

  -- business_status 제약조건
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_business_status_check'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_business_status_check
      CHECK (business_status IS NULL OR business_status IN ('unregistered', 'freelancer', 'simple_vat', 'general_vat'));
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. 컬럼 코멘트
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON COLUMN public.profiles.business_type IS '업태: tutoring(과외), institute(교습소), academy(학원)';
COMMENT ON COLUMN public.profiles.business_status IS '사업자 상태: unregistered(미등록), freelancer(프리랜서/3.3%), simple_vat(간이과세), general_vat(일반과세)';
COMMENT ON COLUMN public.profiles.business_start_date IS '사업 시작일';
COMMENT ON COLUMN public.profiles.cash_receipt_enabled IS '현금영수증 발급 가능 여부';

-- ─────────────────────────────────────────────────────────────────────────────
-- 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'profiles'
  AND column_name IN ('business_type', 'business_status', 'business_start_date', 'cash_receipt_enabled')
ORDER BY ordinal_position;
