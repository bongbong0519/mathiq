-- ══════════════════════════════════════════════════════════════════
--  과외 프로필 영상 URL 컬럼 추가
--
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════

ALTER TABLE public.tutor_profiles
  ADD COLUMN IF NOT EXISTS promo_video_url TEXT;

COMMENT ON COLUMN public.tutor_profiles.promo_video_url IS '홍보 영상 임베드 URL (YouTube/Vimeo)';

-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'tutor_profiles' AND column_name = 'promo_video_url';

-- ══════════════════════════════════════════════════════════════════
