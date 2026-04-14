-- ══════════════════════════════════════
--  patch_admin_balance_policy
--  운영자(admin/staff)가 모든 회원의
--  point_balance / cash_balance 를
--  UPDATE 할 수 있도록 RLS 정책 추가
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- ─────────────────────────────────────
-- 1. 운영자 UPDATE 정책
--    profiles.role = 'admin' 또는 'staff' 인 경우에만
--    point_balance / cash_balance 컬럼 UPDATE 허용
-- ─────────────────────────────────────
DROP POLICY IF EXISTS "admin_update_balance" ON public.profiles;
CREATE POLICY "admin_update_balance"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles AS me
      WHERE me.id = auth.uid()
        AND me.role IN ('admin', 'staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles AS me
      WHERE me.id = auth.uid()
        AND me.role IN ('admin', 'staff')
    )
  );
