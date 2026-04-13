-- ══════════════════════════════════════
--  profiles 테이블 DELETE RLS
--  운영자(admin)가 회원 탈퇴 처리 가능하도록
-- ══════════════════════════════════════

-- 재귀 방지를 위한 SECURITY DEFINER 함수
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- admin이 모든 프로필 삭제 가능
CREATE POLICY "profiles_delete_by_admin"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (public.is_admin());

-- 본인 계정 삭제 (탈퇴)
CREATE POLICY "profiles_delete_self"
  ON public.profiles FOR DELETE
  TO authenticated
  USING (id = auth.uid());
