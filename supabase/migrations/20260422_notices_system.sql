-- ══════════════════════════════════════════════════════════════════
--  공지사항 시스템 (notices) - 1단계 DB 구축
--
--  테이블: notices, notice_reads
--  정책: 전원 읽기, admin만 작성/수정/삭제
--
--  실행: Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 1: notices 테이블                                          │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.notices (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT        NOT NULL,
  content     TEXT        NOT NULL,
  category    TEXT        NOT NULL CHECK (category IN ('important', 'update', 'event', 'general')),
  is_pinned   BOOLEAN     DEFAULT false,    -- 2단계에서 활용 (상단 고정)
  author_id   UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at  TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_notices_created_at ON public.notices(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_is_pinned ON public.notices(is_pinned DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_category ON public.notices(category);

-- RLS 활성화
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;

-- SELECT: 모든 인증 사용자 허용
DROP POLICY IF EXISTS "notices_select" ON public.notices;
CREATE POLICY "notices_select"
  ON public.notices FOR SELECT
  TO authenticated
  USING (true);

-- INSERT: admin만
DROP POLICY IF EXISTS "notices_insert" ON public.notices;
CREATE POLICY "notices_insert"
  ON public.notices FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- UPDATE: admin만
DROP POLICY IF EXISTS "notices_update" ON public.notices;
CREATE POLICY "notices_update"
  ON public.notices FOR UPDATE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- DELETE: admin만
DROP POLICY IF EXISTS "notices_delete" ON public.notices;
CREATE POLICY "notices_delete"
  ON public.notices FOR DELETE
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 2: notice_reads 테이블 (3단계용 선작업)                     │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.notice_reads (
  user_id     UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  notice_id   UUID        REFERENCES public.notices(id) ON DELETE CASCADE NOT NULL,
  read_at     TIMESTAMPTZ DEFAULT now() NOT NULL,
  PRIMARY KEY (user_id, notice_id)
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_notice_reads_user ON public.notice_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_notice_reads_notice ON public.notice_reads(notice_id);

-- RLS 활성화
ALTER TABLE public.notice_reads ENABLE ROW LEVEL SECURITY;

-- SELECT: 본인 읽음 기록만
DROP POLICY IF EXISTS "notice_reads_select" ON public.notice_reads;
CREATE POLICY "notice_reads_select"
  ON public.notice_reads FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- INSERT: 본인만
DROP POLICY IF EXISTS "notice_reads_insert" ON public.notice_reads;
CREATE POLICY "notice_reads_insert"
  ON public.notice_reads FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- DELETE: 본인만
DROP POLICY IF EXISTS "notice_reads_delete" ON public.notice_reads;
CREATE POLICY "notice_reads_delete"
  ON public.notice_reads FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 3: updated_at 자동 갱신 트리거                              │
-- └─────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION update_notices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notices_updated_at ON public.notices;
CREATE TRIGGER trigger_notices_updated_at
  BEFORE UPDATE ON public.notices
  FOR EACH ROW EXECUTE FUNCTION update_notices_updated_at();


-- ══════════════════════════════════════════════════════════════════
--  PostgREST 스키마 리로드
-- ══════════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';


-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- 테이블 확인
-- SELECT tablename FROM pg_tables WHERE tablename IN ('notices', 'notice_reads');

-- RLS 정책 확인
-- SELECT policyname, tablename, cmd FROM pg_policies WHERE tablename IN ('notices', 'notice_reads');
