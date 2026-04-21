-- ══════════════════════════════════════════════════════════════════
--  기존 notices 테이블 보강 + 정책/인덱스/트리거 생성
-- ══════════════════════════════════════════════════════════════════

-- 1. 누락 컬럼 추가
ALTER TABLE public.notices
  ADD COLUMN IF NOT EXISTS category TEXT;

ALTER TABLE public.notices
  ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT false;

-- 2. category CHECK 제약 추가 (기존 데이터에 NULL 있을 수 있으니 먼저 기본값 채우고)
UPDATE public.notices SET category = 'general' WHERE category IS NULL;
ALTER TABLE public.notices ALTER COLUMN category SET NOT NULL;

ALTER TABLE public.notices DROP CONSTRAINT IF EXISTS notices_category_check;
ALTER TABLE public.notices
  ADD CONSTRAINT notices_category_check
  CHECK (category IN ('important', 'update', 'event', 'general'));

-- 3. 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_notices_created_at ON public.notices(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_is_pinned ON public.notices(is_pinned DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notices_category ON public.notices(category);

-- 4. RLS 활성화
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;

-- 5. notices 정책들 (기존 is_admin_user() 함수 재사용)
DROP POLICY IF EXISTS "notices_select" ON public.notices;
CREATE POLICY "notices_select"
  ON public.notices FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "notices_insert" ON public.notices;
CREATE POLICY "notices_insert"
  ON public.notices FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin_user());

DROP POLICY IF EXISTS "notices_update" ON public.notices;
CREATE POLICY "notices_update"
  ON public.notices FOR UPDATE
  TO authenticated
  USING (public.is_admin_user());

DROP POLICY IF EXISTS "notices_delete" ON public.notices;
CREATE POLICY "notices_delete"
  ON public.notices FOR DELETE
  TO authenticated
  USING (public.is_admin_user());

-- 6. notice_reads 테이블 + 정책
CREATE TABLE IF NOT EXISTS public.notice_reads (
  user_id     UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  notice_id   UUID        REFERENCES public.notices(id) ON DELETE CASCADE NOT NULL,
  read_at     TIMESTAMPTZ DEFAULT now() NOT NULL,
  PRIMARY KEY (user_id, notice_id)
);

CREATE INDEX IF NOT EXISTS idx_notice_reads_user ON public.notice_reads(user_id);
CREATE INDEX IF NOT EXISTS idx_notice_reads_notice ON public.notice_reads(notice_id);

ALTER TABLE public.notice_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notice_reads_select" ON public.notice_reads;
CREATE POLICY "notice_reads_select"
  ON public.notice_reads FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "notice_reads_insert" ON public.notice_reads;
CREATE POLICY "notice_reads_insert"
  ON public.notice_reads FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "notice_reads_delete" ON public.notice_reads;
CREATE POLICY "notice_reads_delete"
  ON public.notice_reads FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- 7. updated_at 자동 갱신 트리거
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

-- 8. PostgREST 스키마 리로드
NOTIFY pgrst, 'reload schema';
