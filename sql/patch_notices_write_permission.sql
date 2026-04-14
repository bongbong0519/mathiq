-- ══════════════════════════════════════
--  patch_notices_write_permission
--  공지사항 작성 권한을 admin + staff 로 변경
--  (director 제외)
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- 기존 정책 제거
DROP POLICY IF EXISTS "notices_insert_admin_director" ON public.notices;
DROP POLICY IF EXISTS "notices_update_admin_director" ON public.notices;
DROP POLICY IF EXISTS "notices_insert_admin_staff"    ON public.notices;
DROP POLICY IF EXISTS "notices_update_admin_staff"    ON public.notices;

-- 운영자/운영진만 작성
CREATE POLICY "notices_insert_admin_staff"
  ON public.notices FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'staff')
  );

-- 운영자/운영진만 수정
CREATE POLICY "notices_update_admin_staff"
  ON public.notices FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'staff')
  );
