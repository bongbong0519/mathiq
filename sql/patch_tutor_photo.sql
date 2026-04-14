-- ══════════════════════════════════════
--  patch_tutor_photo
--  tutor_profiles 테이블에 photo_url 컬럼 추가
--  Supabase Storage 'tutor-photos' 버킷 정책 설정
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- ─────────────────────────────────────
-- 1. tutor_profiles 에 photo_url 컬럼 추가
-- ─────────────────────────────────────
ALTER TABLE public.tutor_profiles
  ADD COLUMN IF NOT EXISTS photo_url TEXT;

-- ─────────────────────────────────────
-- 2. Storage 버킷 생성 (이미 있으면 무시)
--    public: true → getPublicUrl() 사용 가능
-- ─────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('tutor-photos', 'tutor-photos', true)
ON CONFLICT (id) DO NOTHING;

-- ─────────────────────────────────────
-- 3. Storage RLS 정책
--    읽기: 전체 공개 (비로그인 포함)
--    업로드/수정/삭제: 본인 폴더만 ({user_id}/*)
-- ─────────────────────────────────────
DROP POLICY IF EXISTS "tutor_photos_select_public" ON storage.objects;
CREATE POLICY "tutor_photos_select_public"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'tutor-photos');

DROP POLICY IF EXISTS "tutor_photos_insert_own" ON storage.objects;
CREATE POLICY "tutor_photos_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'tutor-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "tutor_photos_update_own" ON storage.objects;
CREATE POLICY "tutor_photos_update_own"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'tutor-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "tutor_photos_delete_own" ON storage.objects;
CREATE POLICY "tutor_photos_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'tutor-photos'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
