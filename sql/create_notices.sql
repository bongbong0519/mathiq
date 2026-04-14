-- ══════════════════════════════════════
--  notices: 공지사항 테이블
--  로그인 없이 전체 읽기 가능 (public SELECT)
--  작성: admin, director / 수정: admin, director / 삭제: admin
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.notices (
  id         UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  title      TEXT        NOT NULL,
  content    TEXT        NOT NULL,
  author_id  UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;

-- 전체 공개 읽기 (비로그인 포함)
CREATE POLICY "notices_select_public"
  ON public.notices FOR SELECT
  TO public
  USING (true);

-- 운영자/원장만 작성
CREATE POLICY "notices_insert_admin_director"
  ON public.notices FOR INSERT
  TO authenticated
  WITH CHECK (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'director')
  );

-- 운영자/원장만 수정
CREATE POLICY "notices_update_admin_director"
  ON public.notices FOR UPDATE
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'director')
  );

-- 운영자만 삭제
CREATE POLICY "notices_delete_admin"
  ON public.notices FOR DELETE
  TO authenticated
  USING (
    (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
  );

-- profiles JOIN을 위한 SELECT 허용 확인 (이미 있으면 무시)
-- profiles 테이블의 public SELECT 정책이 있어야 author 이름 표시 가능
