-- ══════════════════════════════════════
--  organizations 테이블 생성
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.organizations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'academy'
    CHECK (type IN ('academy', 'school', 'tutoring', 'other')),
  contact_name TEXT,
  phone TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE public.organizations IS '학교/학원/교습소 등 기관 관리 테이블';
COMMENT ON COLUMN public.organizations.type IS 'academy=학원, school=학교, tutoring=교습소, other=기타';
COMMENT ON COLUMN public.organizations.status IS 'pending=대기, approved=승인, rejected=거절';

-- ══════════════════════════════════════
--  RLS 활성화
-- ══════════════════════════════════════

ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;

-- 읽기: 로그인한 사용자 누구나 조회 가능
CREATE POLICY "organizations_select"
  ON public.organizations FOR SELECT
  TO authenticated
  USING (true);

-- 삽입: admin 역할만 가능
CREATE POLICY "organizations_insert"
  ON public.organizations FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- 수정: admin 역할만 가능
CREATE POLICY "organizations_update"
  ON public.organizations FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- 삭제: admin 역할만 가능
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
