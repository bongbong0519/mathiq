-- ══════════════════════════════════════
--  patch_student_contact
--  학생 연락처 열람 기능 (500 파이포인트 차감)
--  1. profiles.point_balance 컬럼 추가
--  2. tutor_contact_views 테이블 생성
--  3. deduct_points RPC 함수 (SECURITY DEFINER)
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- ─────────────────────────────────────
-- 1. profiles 에 point_balance 컬럼 추가
-- ─────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS point_balance INTEGER NOT NULL DEFAULT 0;

-- ─────────────────────────────────────
-- 2. tutor_contact_views 테이블 생성
--    tutor_id: 열람한 선생님 (profiles.id)
--    tutee_id: 열람된 학생 (tutee_profiles.id)
--    UNIQUE(tutor_id, tutee_id) → 중복 열람 방지
-- ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tutor_contact_views (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  tutor_id   UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  tutee_id   UUID        REFERENCES public.tutee_profiles(id) ON DELETE CASCADE NOT NULL,
  viewed_at  TIMESTAMPTZ DEFAULT now() NOT NULL,
  UNIQUE (tutor_id, tutee_id)
);

ALTER TABLE public.tutor_contact_views ENABLE ROW LEVEL SECURITY;

-- 본인이 열람한 기록만 조회 가능
DROP POLICY IF EXISTS "contact_views_select_own" ON public.tutor_contact_views;
CREATE POLICY "contact_views_select_own"
  ON public.tutor_contact_views FOR SELECT
  TO authenticated
  USING (tutor_id = auth.uid());

-- 본인 명의로만 삽입 가능
DROP POLICY IF EXISTS "contact_views_insert_own" ON public.tutor_contact_views;
CREATE POLICY "contact_views_insert_own"
  ON public.tutor_contact_views FOR INSERT
  TO authenticated
  WITH CHECK (tutor_id = auth.uid());

-- ─────────────────────────────────────
-- 3. deduct_points RPC 함수
--    SECURITY DEFINER: 클라이언트가 직접 UPDATE 없이
--    서버에서 안전하게 포인트 차감
--    포인트 부족 시 예외 발생 → 클라이언트에서 에러 처리
-- ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.deduct_points(amount INTEGER)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET point_balance = point_balance - amount
  WHERE id = auth.uid()
    AND point_balance >= amount;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'insufficient_points'
      USING HINT = '포인트가 부족합니다';
  END IF;
END;
$$;

-- RPC 함수를 authenticated 유저만 실행 가능하도록 권한 설정
REVOKE EXECUTE ON FUNCTION public.deduct_points(INTEGER) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.deduct_points(INTEGER) TO authenticated;
