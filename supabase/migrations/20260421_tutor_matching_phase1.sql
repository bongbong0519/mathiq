-- ══════════════════════════════════════════════════════════════════
--  과외 매칭 Phase 1 - DB 스키마 마이그레이션
--
--  실행 순서: 섹션 1 → 2 → 3 → 4 → 5 → 6 순서대로
--  주의: 각 섹션별로 나눠서 실행 권장 (에러 발생 시 롤백 용이)
--
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 1: 기존 데이터 정리                                        │
-- │  tutor_contact_views 레코드 삭제 (테이블 구조는 유지)             │
-- └─────────────────────────────────────────────────────────────────┘

DELETE FROM public.tutor_contact_views;


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 2: profiles 테이블에 phone 컬럼 추가                        │
-- │  학부모/선생님 연락처 공개에 사용                                  │
-- └─────────────────────────────────────────────────────────────────┘

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS phone TEXT;


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 3: tutee_profiles 배열 변환                                 │
-- │  subject, region 컬럼을 TEXT → TEXT[] 변환                       │
-- │  ⚠️ 주의: 기존 데이터가 있으면 배열로 래핑됨                       │
-- └─────────────────────────────────────────────────────────────────┘

-- subject 컬럼: TEXT → TEXT[]
ALTER TABLE public.tutee_profiles
  ALTER COLUMN subject TYPE TEXT[]
  USING CASE WHEN subject IS NULL THEN NULL ELSE ARRAY[subject] END;

-- region 컬럼: TEXT → TEXT[]
ALTER TABLE public.tutee_profiles
  ALTER COLUMN region TYPE TEXT[]
  USING CASE WHEN region IS NULL THEN NULL ELSE ARRAY[region] END;

-- GIN 인덱스 생성 (배열 검색 성능)
CREATE INDEX IF NOT EXISTS idx_tutee_profiles_subject ON public.tutee_profiles USING GIN (subject);
CREATE INDEX IF NOT EXISTS idx_tutee_profiles_region ON public.tutee_profiles USING GIN (region);


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 4: tutor_match_requests 테이블 생성                         │
-- │  학부모 → 선생님 매칭 신청                                        │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.tutor_match_requests (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,  -- 학부모
  tutor_id      UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,  -- 선생님
  message       TEXT,                                                                    -- 신청 메시지
  status        TEXT        DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected','cancelled')),
  created_at    TIMESTAMPTZ DEFAULT now() NOT NULL,
  responded_at  TIMESTAMPTZ
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_match_requests_tutor ON public.tutor_match_requests(tutor_id, status);
CREATE INDEX IF NOT EXISTS idx_match_requests_requester ON public.tutor_match_requests(requester_id, status);
CREATE INDEX IF NOT EXISTS idx_match_requests_created ON public.tutor_match_requests(created_at DESC);

-- RLS 활성화
ALTER TABLE public.tutor_match_requests ENABLE ROW LEVEL SECURITY;

-- 선생님: 본인에게 온 신청 조회
DROP POLICY IF EXISTS "match_requests_tutor_select" ON public.tutor_match_requests;
CREATE POLICY "match_requests_tutor_select"
  ON public.tutor_match_requests FOR SELECT
  TO authenticated
  USING (tutor_id = auth.uid());

-- 선생님: 본인에게 온 신청 상태 업데이트 (수락/거절)
DROP POLICY IF EXISTS "match_requests_tutor_update" ON public.tutor_match_requests;
CREATE POLICY "match_requests_tutor_update"
  ON public.tutor_match_requests FOR UPDATE
  TO authenticated
  USING (tutor_id = auth.uid());

-- 학부모: 본인이 보낸 신청 조회
DROP POLICY IF EXISTS "match_requests_requester_select" ON public.tutor_match_requests;
CREATE POLICY "match_requests_requester_select"
  ON public.tutor_match_requests FOR SELECT
  TO authenticated
  USING (requester_id = auth.uid());

-- 학부모: 신청 생성
DROP POLICY IF EXISTS "match_requests_requester_insert" ON public.tutor_match_requests;
CREATE POLICY "match_requests_requester_insert"
  ON public.tutor_match_requests FOR INSERT
  TO authenticated
  WITH CHECK (requester_id = auth.uid());

-- 학부모: 본인이 보낸 신청 취소 (pending 상태만)
DROP POLICY IF EXISTS "match_requests_requester_update" ON public.tutor_match_requests;
CREATE POLICY "match_requests_requester_update"
  ON public.tutor_match_requests FOR UPDATE
  TO authenticated
  USING (requester_id = auth.uid() AND status = 'pending');

-- staff(관리자): 전체 조회
DROP POLICY IF EXISTS "match_requests_staff_select" ON public.tutor_match_requests;
CREATE POLICY "match_requests_staff_select"
  ON public.tutor_match_requests FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 5: tutor_matches 테이블 생성                                │
-- │  성사된 매칭 기록 (수락 시점 + 성사 신고)                          │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.tutor_matches (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id        UUID        REFERENCES public.tutor_match_requests(id) ON DELETE CASCADE NOT NULL,
  tutor_id          UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  requester_id      UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  confirmed_at      TIMESTAMPTZ DEFAULT now() NOT NULL,   -- 수락 시점 (선생님 500p 차감)
  reward_claimed    BOOLEAN     DEFAULT false,            -- 학부모 성사 신고 여부
  reward_claimed_at TIMESTAMPTZ,                          -- 성사 신고 시점
  created_at        TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_matches_tutor ON public.tutor_matches(tutor_id);
CREATE INDEX IF NOT EXISTS idx_matches_requester ON public.tutor_matches(requester_id);
CREATE INDEX IF NOT EXISTS idx_matches_request ON public.tutor_matches(request_id);

-- RLS 활성화
ALTER TABLE public.tutor_matches ENABLE ROW LEVEL SECURITY;

-- 선생님: 본인 매칭 조회
DROP POLICY IF EXISTS "matches_tutor_select" ON public.tutor_matches;
CREATE POLICY "matches_tutor_select"
  ON public.tutor_matches FOR SELECT
  TO authenticated
  USING (tutor_id = auth.uid());

-- 선생님: 매칭 생성 (수락 시)
DROP POLICY IF EXISTS "matches_tutor_insert" ON public.tutor_matches;
CREATE POLICY "matches_tutor_insert"
  ON public.tutor_matches FOR INSERT
  TO authenticated
  WITH CHECK (tutor_id = auth.uid());

-- 학부모: 본인 매칭 조회
DROP POLICY IF EXISTS "matches_requester_select" ON public.tutor_matches;
CREATE POLICY "matches_requester_select"
  ON public.tutor_matches FOR SELECT
  TO authenticated
  USING (requester_id = auth.uid());

-- 학부모: 성사 신고 업데이트
DROP POLICY IF EXISTS "matches_requester_update" ON public.tutor_matches;
CREATE POLICY "matches_requester_update"
  ON public.tutor_matches FOR UPDATE
  TO authenticated
  USING (requester_id = auth.uid() AND reward_claimed = false);

-- staff(관리자): 전체 조회
DROP POLICY IF EXISTS "matches_staff_select" ON public.tutor_matches;
CREATE POLICY "matches_staff_select"
  ON public.tutor_matches FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 6: add_points RPC 함수 (성사 신고 리워드용)                  │
-- │  SECURITY DEFINER: 클라이언트가 직접 UPDATE 없이 안전하게 지급      │
-- └─────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION public.add_points(p_user_id UUID, p_amount INTEGER, p_reason TEXT DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 포인트 지급
  UPDATE public.profiles
  SET point_balance = COALESCE(point_balance, 0) + p_amount
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found'
      USING HINT = '사용자를 찾을 수 없습니다';
  END IF;

  -- 포인트 이력 테이블이 있으면 여기에 기록 추가 가능
  -- (현재는 없으므로 생략)
END;
$$;

-- RPC 함수 권한: authenticated 유저만 실행 가능
REVOKE EXECUTE ON FUNCTION public.add_points(UUID, INTEGER, TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.add_points(UUID, INTEGER, TEXT) TO authenticated;


-- ══════════════════════════════════════════════════════════════════
--  마이그레이션 완료
--
--  검증 쿼리:
--  1. SELECT COUNT(*) FROM tutor_contact_views;  -- 0이어야 함
--  2. SELECT column_name FROM information_schema.columns
--     WHERE table_name = 'profiles' AND column_name = 'phone';
--  3. SELECT data_type FROM information_schema.columns
--     WHERE table_name = 'tutee_profiles' AND column_name = 'subject';  -- ARRAY
--  4. SELECT * FROM tutor_match_requests LIMIT 1;  -- 테이블 존재 확인
--  5. SELECT * FROM tutor_matches LIMIT 1;  -- 테이블 존재 확인
--  6. SELECT proname FROM pg_proc WHERE proname = 'add_points';  -- 함수 존재
-- ══════════════════════════════════════════════════════════════════
