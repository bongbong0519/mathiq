-- ══════════════════════════════════════
--  캠퍼스 티어 마이그레이션
--  'free' → 'campus' 변경
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- 1. 기존 CHECK 제약조건 삭제
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_subscription_tier_check;

-- 2. 기존 'free' 값을 'campus'로 변경
UPDATE public.profiles
  SET subscription_tier = 'campus'
  WHERE subscription_tier = 'free';

-- 3. 새 CHECK 제약조건 추가 (campus 포함)
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_subscription_tier_check
  CHECK (subscription_tier IN ('campus','basic','standard','premium','pro'));

-- 4. DEFAULT 값도 'campus'로 변경
ALTER TABLE public.profiles
  ALTER COLUMN subscription_tier SET DEFAULT 'campus';
