-- ══════════════════════════════════════
--  patch_tutor_subject_region_array
--  tutor_profiles.subject, region 컬럼을
--  TEXT → TEXT[] (배열) 타입으로 변경
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- ─────────────────────────────────────
-- 1. subject 컬럼: TEXT → TEXT[]
--    기존 단일 값은 1-element 배열로 마이그레이션
-- ─────────────────────────────────────
ALTER TABLE public.tutor_profiles
  ALTER COLUMN subject TYPE TEXT[]
  USING CASE WHEN subject IS NULL THEN NULL ELSE ARRAY[subject] END;

-- ─────────────────────────────────────
-- 2. region 컬럼: TEXT → TEXT[]
--    기존 단일 값은 1-element 배열로 마이그레이션
-- ─────────────────────────────────────
ALTER TABLE public.tutor_profiles
  ALTER COLUMN region TYPE TEXT[]
  USING CASE WHEN region IS NULL THEN NULL ELSE ARRAY[region] END;

-- ─────────────────────────────────────
-- 3. GIN 인덱스 생성 (contains / overlaps 쿼리 성능)
-- ─────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_subject ON public.tutor_profiles USING GIN (subject);
CREATE INDEX IF NOT EXISTS idx_tutor_profiles_region  ON public.tutor_profiles USING GIN (region);
