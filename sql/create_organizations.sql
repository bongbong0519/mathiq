-- ══════════════════════════════════════
--  organizations 테이블 (기관 중심 구조)
-- ══════════════════════════════════════

-- 기존 테이블이 있으면 삭제 (초기 세팅용)
DROP TABLE IF EXISTS public.organizations CASCADE;

CREATE TABLE public.organizations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'academy'
    CHECK (type IN ('academy', 'school', 'tutoring', 'other')),
  owner_id UUID REFERENCES auth.users(id),
  contact_name TEXT,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.organizations IS '학교/학원/교습소 등 기관 관리 테이블';
COMMENT ON COLUMN public.organizations.owner_id IS '기관 대표(원장님) user_id';
COMMENT ON COLUMN public.organizations.type IS 'academy=학원, school=학교, tutoring=교습소, other=기타';

-- ══════════════════════════════════════
--  profiles 테이블에 organization_id 추가
-- ══════════════════════════════════════

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES public.organizations(id);

COMMENT ON COLUMN public.profiles.organization_id IS '소속 기관 ID (원장님/선생님 모두 사용)';

-- ══════════════════════════════════════
--  RLS 정책
-- ══════════════════════════════════════

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- 읽기: 누구나 (비로그인 회원가입 화면에서 기관 검색 필요)
CREATE POLICY "organizations_select"
  ON public.organizations FOR SELECT
  TO public
  USING (true);

-- 삽입: 누구나 (회원가입 시 기관 생성)
CREATE POLICY "organizations_insert"
  ON public.organizations FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- 수정: admin 또는 해당 기관 owner
CREATE POLICY "organizations_update"
  ON public.organizations FOR UPDATE
  TO authenticated
  USING (
    owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- 삭제: admin만
CREATE POLICY "organizations_delete"
  ON public.organizations FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );
