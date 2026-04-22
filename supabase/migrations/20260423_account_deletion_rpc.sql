-- ══════════════════════════════════════════════════════════════════
--  계정 탈퇴 처리 RPC 함수
--
--  SECURITY DEFINER로 RLS 우회하여 원자성 있게 처리
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.process_account_deletion(
  p_user_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_point_balance INTEGER;
  v_cash_balance INTEGER;
  v_student_count INTEGER;
  v_deletion_id UUID;
  v_org_id UUID;
BEGIN
  -- 본인 확인 (다른 사람 계정 삭제 방지)
  IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
    RAISE EXCEPTION '권한이 없습니다';
  END IF;

  -- 현재 포인트/캐시/기관 조회
  SELECT
    COALESCE(point_balance, 0),
    COALESCE(cash_balance, 0),
    organization_id
  INTO v_point_balance, v_cash_balance, v_org_id
  FROM public.profiles
  WHERE id = p_user_id;

  -- 이미 탈퇴된 계정인지 확인
  IF EXISTS (SELECT 1 FROM public.profiles WHERE id = p_user_id AND deleted_at IS NOT NULL) THEN
    RAISE EXCEPTION '이미 탈퇴된 계정입니다';
  END IF;

  -- 담당 학생 수 조회
  SELECT COUNT(*) INTO v_student_count
  FROM public.students
  WHERE teacher_id = p_user_id;

  -- 1. 스냅샷 저장
  INSERT INTO public.account_deletions (
    user_id,
    snapshot_point_balance,
    snapshot_cash_balance,
    reason
  ) VALUES (
    p_user_id,
    v_point_balance,
    v_cash_balance,
    p_reason
  ) RETURNING id INTO v_deletion_id;

  -- 2. 학생-강사 관계 해제 (RLS 우회)
  UPDATE public.students
  SET teacher_id = NULL
  WHERE teacher_id = p_user_id;

  -- 3. 학원 소속 해제 (organization_id가 있는 경우)
  IF v_org_id IS NOT NULL THEN
    UPDATE public.profiles
    SET organization_id = NULL
    WHERE id = p_user_id;
  END IF;

  -- 4. 탈퇴 마킹 + 잔액 0으로
  UPDATE public.profiles
  SET
    deleted_at = NOW(),
    deletion_reason = p_reason,
    point_balance = 0,
    cash_balance = 0
  WHERE id = p_user_id;

  -- 결과 반환
  RETURN json_build_object(
    'success', true,
    'deletion_id', v_deletion_id,
    'students_released', v_student_count,
    'points_snapshot', v_point_balance,
    'cash_snapshot', v_cash_balance
  );

EXCEPTION WHEN OTHERS THEN
  -- 에러 발생 시 롤백되고 에러 메시지 반환
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 함수 설명
COMMENT ON FUNCTION public.process_account_deletion IS '계정 탈퇴 원자적 처리 (학생 관계 해제 + 스냅샷 저장 + 탈퇴 마킹)';

-- 인증된 사용자만 호출 가능
GRANT EXECUTE ON FUNCTION public.process_account_deletion TO authenticated;


-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- 함수 존재 확인
-- SELECT proname FROM pg_proc WHERE proname = 'process_account_deletion';

-- 테스트 (실제로 실행하지 말 것 - 탈퇴됨!)
-- SELECT public.process_account_deletion('your-user-id', '테스트 탈퇴');

-- ══════════════════════════════════════════════════════════════════
