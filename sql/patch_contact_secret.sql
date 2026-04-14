-- ══════════════════════════════════════
--  patch_contact_secret: 문의하기 비밀글 기능
--  posts 테이블에 is_secret 컬럼 추가
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_secret BOOLEAN DEFAULT false;
