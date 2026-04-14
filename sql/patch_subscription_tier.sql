-- ══════════════════════════════════════
--  patch_subscription_tier
--  구독 티어 및 AI 월 사용 횟수 추적
--  1. profiles.subscription_tier  (free/basic/standard/premium/pro)
--  2. profiles.ai_usage_count     (이번 달 AI 유사문제 생성 횟수)
--  3. profiles.ai_usage_reset_at  (카운터 리셋 기준 시점)
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- ─────────────────────────────────────
-- 1. subscription_tier 컬럼 추가
-- ─────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'free'
  CHECK (subscription_tier IN ('free','basic','standard','premium','pro'));

-- ─────────────────────────────────────
-- 2. AI 유사문제 월 사용 횟수 컬럼 추가
-- ─────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS ai_usage_count INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS ai_usage_reset_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- ─────────────────────────────────────
-- 3. 운영자(admin/staff)가 subscription_tier 도 UPDATE 가능하도록
--    patch_admin_balance_policy.sql 의 정책이 이미 profiles 전체 행
--    UPDATE 를 허용하므로 별도 정책 불필요.
--    (필요 시 해당 파일 재실행)
-- ─────────────────────────────────────
