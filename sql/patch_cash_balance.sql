-- ══════════════════════════════════════
--  patch_cash_balance
--  profiles 테이블에 cash_balance 컬럼 추가
--  (point_balance 는 patch_student_contact.sql 에서 이미 추가됨)
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS cash_balance INTEGER NOT NULL DEFAULT 0;
