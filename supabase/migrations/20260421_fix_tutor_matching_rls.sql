-- ══════════════════════════════════════════════════════════════════
--  과외 매칭 RLS 정책 보완
--
--  버그: 학부모 매칭 성사 신고 시 RLS 위반 에러
--  원인: tutor_matches UPDATE 정책 누락
--
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 1: tutor_matches UPDATE 정책 추가                          │
-- │  학부모가 본인 매칭의 reward_claimed 업데이트 허용                 │
-- └─────────────────────────────────────────────────────────────────┘

-- 기존 정책 제거 (있으면)
DROP POLICY IF EXISTS "matches_requester_update" ON public.tutor_matches;
DROP POLICY IF EXISTS "matches_update_own_reward" ON public.tutor_matches;

-- 새 UPDATE 정책: 학부모가 본인 매칭 업데이트 (성사 신고)
CREATE POLICY "matches_requester_update"
ON public.tutor_matches
FOR UPDATE
TO authenticated
USING (requester_id = auth.uid())
WITH CHECK (requester_id = auth.uid());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 2: tutor_match_requests UPDATE 정책 보완                   │
-- │  학부모: 본인 신청 취소 / 선생님: 수락·거절                        │
-- └─────────────────────────────────────────────────────────────────┘

-- 기존 정책 제거
DROP POLICY IF EXISTS "match_requests_requester_update" ON public.tutor_match_requests;
DROP POLICY IF EXISTS "match_requests_tutor_update" ON public.tutor_match_requests;

-- 학부모: 본인이 보낸 신청 취소 (pending 상태만)
CREATE POLICY "match_requests_requester_update"
ON public.tutor_match_requests
FOR UPDATE
TO authenticated
USING (requester_id = auth.uid() AND status = 'pending')
WITH CHECK (requester_id = auth.uid());

-- 선생님: 본인에게 온 신청 수락/거절
CREATE POLICY "match_requests_tutor_update"
ON public.tutor_match_requests
FOR UPDATE
TO authenticated
USING (tutor_id = auth.uid())
WITH CHECK (tutor_id = auth.uid());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 3: add_points RPC 함수 SECURITY DEFINER 확인               │
-- │  이미 SECURITY DEFINER로 생성되어 있어야 함                       │
-- │  아래는 혹시 누락된 경우를 대비한 재설정                           │
-- └─────────────────────────────────────────────────────────────────┘

-- add_points 함수가 SECURITY DEFINER인지 확인 후, 아니면 재생성
-- (기존 마이그레이션에서 이미 SECURITY DEFINER로 생성했으므로 보통 불필요)
-- 만약 문제가 있으면 아래 주석 해제 후 실행:

/*
CREATE OR REPLACE FUNCTION public.add_points(p_user_id UUID, p_amount INTEGER, p_reason TEXT DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.profiles
  SET point_balance = COALESCE(point_balance, 0) + p_amount
  WHERE id = p_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found'
      USING HINT = '사용자를 찾을 수 없습니다';
  END IF;
END;
$$;
*/


-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리 (실행 후 확인용)
-- ══════════════════════════════════════════════════════════════════

-- 1. tutor_matches 정책 확인
-- SELECT policyname, cmd FROM pg_policies WHERE tablename = 'tutor_matches';
-- → matches_requester_update (UPDATE) 있어야 함

-- 2. tutor_match_requests 정책 확인
-- SELECT policyname, cmd FROM pg_policies WHERE tablename = 'tutor_match_requests';
-- → match_requests_requester_update (UPDATE), match_requests_tutor_update (UPDATE) 있어야 함

-- 3. add_points 함수 SECURITY DEFINER 확인
-- SELECT proname, prosecdef FROM pg_proc WHERE proname = 'add_points';
-- → prosecdef = true 여야 함

-- ══════════════════════════════════════════════════════════════════
