-- ══════════════════════════════════════
--  패치: organizations SELECT 정책을 public으로 변경
--  이유: 회원가입 화면(비로그인)에서 기관 검색이 필요
-- ══════════════════════════════════════

DROP POLICY IF EXISTS "organizations_select" ON public.organizations;

CREATE POLICY "organizations_select"
  ON public.organizations FOR SELECT
  TO public
  USING (true);
