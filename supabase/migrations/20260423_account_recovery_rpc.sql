-- ══════════════════════════════════════════════════════════════════
--  계정 복구 처리 RPC 함수
--
--  SECURITY DEFINER로 RLS 우회하여 원자성 있게 처리
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.process_account_recovery(
  p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_deletion_id UUID;
  v_snapshot_points INTEGER;
  v_snapshot_cash INTEGER;
  v_recover_points INTEGER;
BEGIN
  -- 본인 확인
  IF auth.uid() IS NULL OR auth.uid() != p_user_id THEN
    RAISE EXCEPTION '권한이 없습니다';
  END IF;

  -- 이미 활성 계정이면 에러
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_user_id AND deleted_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION '탈퇴된 계정이 아닙니다';
  END IF;

  -- 최근 탈퇴 기록 찾기 (recovered_at IS NULL인 것 중 가장 최근)
  SELECT id, snapshot_point_balance, snapshot_cash_balance
  INTO v_deletion_id, v_snapshot_points, v_snapshot_cash
  FROM public.account_deletions
  WHERE user_id = p_user_id
    AND recovered_at IS NULL
  ORDER BY deleted_at DESC
  LIMIT 1;

  IF v_deletion_id IS NULL THEN
    RAISE EXCEPTION '복구 가능한 탈퇴 기록이 없습니다';
  END IF;

  -- 50% 계산
  v_recover_points := FLOOR(COALESCE(v_snapshot_points, 0) * 0.5);

  -- 1. profiles 복구
  UPDATE public.profiles SET
    deleted_at = NULL,
    deletion_reason = NULL,
    point_balance = v_recover_points,
    cash_balance = COALESCE(v_snapshot_cash, 0)
  WHERE id = p_user_id;

  -- 2. account_deletions 업데이트
  UPDATE public.account_deletions SET
    recovered_at = NOW(),
    recovery_type = 'auto_50',
    recovered_points = v_recover_points
  WHERE id = v_deletion_id;

  -- 결과 반환
  RETURN json_build_object(
    'success', true,
    'deletion_id', v_deletion_id,
    'recovered_points', v_recover_points,
    'recovered_cash', COALESCE(v_snapshot_cash, 0)
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
COMMENT ON FUNCTION public.process_account_recovery IS '계정 복구 원자적 처리 (profiles 복구 + account_deletions 업데이트)';

-- 인증된 사용자만 호출 가능
GRANT EXECUTE ON FUNCTION public.process_account_recovery TO authenticated;


-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- 함수 존재 확인
-- SELECT proname FROM pg_proc WHERE proname = 'process_account_recovery';

-- 테스트 (실제로 실행하지 말 것 - 복구됨!)
-- SELECT public.process_account_recovery('your-user-id');

-- ══════════════════════════════════════════════════════════════════
