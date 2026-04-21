-- ══════════════════════════════════════════════════════════════════
--  게시판 + 1:1 문의 시스템 - DB 스키마
--
--  실행 순서: 섹션 1 → 2 → 3 → 4 순서대로
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 1: feedback_posts 테이블 (게시글)                          │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.feedback_posts (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id       UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  category        TEXT        NOT NULL CHECK (category IN ('bug','question','suggestion','notice')),
  title           TEXT        NOT NULL,
  content         TEXT        NOT NULL,
  attachment_urls TEXT[],

  -- 버그 신고 전용 필드
  bug_screen      TEXT,       -- 어떤 화면에서 발생했는지
  bug_browser     TEXT,       -- 브라우저 정보

  -- 건의사항 전용 필드
  suggestion_status TEXT      CHECK (suggestion_status IN ('reviewing','accepted','in_progress','completed','rejected')),
  vote_count      INTEGER     DEFAULT 0,

  -- 공통 필드
  view_count      INTEGER     DEFAULT 0,
  is_pinned       BOOLEAN     DEFAULT false,
  is_resolved     BOOLEAN     DEFAULT false,

  created_at      TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_posts_category ON public.feedback_posts(category);
CREATE INDEX IF NOT EXISTS idx_posts_author ON public.feedback_posts(author_id);
CREATE INDEX IF NOT EXISTS idx_posts_created ON public.feedback_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_votes ON public.feedback_posts(vote_count DESC);
CREATE INDEX IF NOT EXISTS idx_posts_pinned ON public.feedback_posts(is_pinned DESC, created_at DESC);

-- RLS 활성화
ALTER TABLE public.feedback_posts ENABLE ROW LEVEL SECURITY;

-- 모든 인증 사용자: 조회
DROP POLICY IF EXISTS "posts_select" ON public.feedback_posts;
CREATE POLICY "posts_select"
  ON public.feedback_posts FOR SELECT
  TO authenticated
  USING (true);

-- 인증 사용자: 본인 글 작성 (공지사항 제외)
DROP POLICY IF EXISTS "posts_insert" ON public.feedback_posts;
CREATE POLICY "posts_insert"
  ON public.feedback_posts FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id = auth.uid() AND
    (category != 'notice' OR EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff'
    ))
  );

-- 본인 글만 수정 (staff는 전체 수정 가능)
DROP POLICY IF EXISTS "posts_update" ON public.feedback_posts;
CREATE POLICY "posts_update"
  ON public.feedback_posts FOR UPDATE
  TO authenticated
  USING (
    author_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff')
  );

-- 본인 글만 삭제 (staff는 전체 삭제 가능)
DROP POLICY IF EXISTS "posts_delete" ON public.feedback_posts;
CREATE POLICY "posts_delete"
  ON public.feedback_posts FOR DELETE
  TO authenticated
  USING (
    author_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff')
  );


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 2: feedback_comments 테이블 (댓글)                         │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.feedback_comments (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id         UUID        REFERENCES public.feedback_posts(id) ON DELETE CASCADE NOT NULL,
  author_id       UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  content         TEXT        NOT NULL,
  is_official     BOOLEAN     DEFAULT false,  -- 운영자 공식 답변
  created_at      TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_comments_post ON public.feedback_comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_created ON public.feedback_comments(created_at);

-- RLS 활성화
ALTER TABLE public.feedback_comments ENABLE ROW LEVEL SECURITY;

-- 모든 인증 사용자: 조회
DROP POLICY IF EXISTS "comments_select" ON public.feedback_comments;
CREATE POLICY "comments_select"
  ON public.feedback_comments FOR SELECT
  TO authenticated
  USING (true);

-- 인증 사용자: 댓글 작성
DROP POLICY IF EXISTS "comments_insert" ON public.feedback_comments;
CREATE POLICY "comments_insert"
  ON public.feedback_comments FOR INSERT
  TO authenticated
  WITH CHECK (author_id = auth.uid());

-- 본인 댓글만 수정
DROP POLICY IF EXISTS "comments_update" ON public.feedback_comments;
CREATE POLICY "comments_update"
  ON public.feedback_comments FOR UPDATE
  TO authenticated
  USING (author_id = auth.uid());

-- 본인 댓글만 삭제 (staff는 전체 삭제 가능)
DROP POLICY IF EXISTS "comments_delete" ON public.feedback_comments;
CREATE POLICY "comments_delete"
  ON public.feedback_comments FOR DELETE
  TO authenticated
  USING (
    author_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff')
  );


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 3: feedback_votes 테이블 (건의사항 추천)                    │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.feedback_votes (
  post_id         UUID        REFERENCES public.feedback_posts(id) ON DELETE CASCADE NOT NULL,
  user_id         UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  voted_at        TIMESTAMPTZ DEFAULT now() NOT NULL,
  PRIMARY KEY (post_id, user_id)
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_votes_post ON public.feedback_votes(post_id);

-- RLS 활성화
ALTER TABLE public.feedback_votes ENABLE ROW LEVEL SECURITY;

-- 모든 인증 사용자: 조회
DROP POLICY IF EXISTS "votes_select" ON public.feedback_votes;
CREATE POLICY "votes_select"
  ON public.feedback_votes FOR SELECT
  TO authenticated
  USING (true);

-- 인증 사용자: 투표
DROP POLICY IF EXISTS "votes_insert" ON public.feedback_votes;
CREATE POLICY "votes_insert"
  ON public.feedback_votes FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

-- 본인 투표만 취소
DROP POLICY IF EXISTS "votes_delete" ON public.feedback_votes;
CREATE POLICY "votes_delete"
  ON public.feedback_votes FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 4: inquiries + inquiry_messages 테이블 (1:1 문의)          │
-- └─────────────────────────────────────────────────────────────────┘

-- 1:1 문의 (티켓)
CREATE TABLE IF NOT EXISTS public.inquiries (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id       UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  subject         TEXT        NOT NULL,
  category        TEXT,       -- payment, account, etc.
  status          TEXT        DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved','closed')),
  created_at      TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at      TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_inquiries_author ON public.inquiries(author_id);
CREATE INDEX IF NOT EXISTS idx_inquiries_status ON public.inquiries(status);
CREATE INDEX IF NOT EXISTS idx_inquiries_created ON public.inquiries(created_at DESC);

-- RLS 활성화
ALTER TABLE public.inquiries ENABLE ROW LEVEL SECURITY;

-- 본인 문의만 조회 (staff는 전체)
DROP POLICY IF EXISTS "inquiries_select" ON public.inquiries;
CREATE POLICY "inquiries_select"
  ON public.inquiries FOR SELECT
  TO authenticated
  USING (
    author_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff')
  );

-- 본인 문의 생성
DROP POLICY IF EXISTS "inquiries_insert" ON public.inquiries;
CREATE POLICY "inquiries_insert"
  ON public.inquiries FOR INSERT
  TO authenticated
  WITH CHECK (author_id = auth.uid());

-- 본인 또는 staff만 수정
DROP POLICY IF EXISTS "inquiries_update" ON public.inquiries;
CREATE POLICY "inquiries_update"
  ON public.inquiries FOR UPDATE
  TO authenticated
  USING (
    author_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff')
  );

-- 문의 메시지
CREATE TABLE IF NOT EXISTS public.inquiry_messages (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  inquiry_id      UUID        REFERENCES public.inquiries(id) ON DELETE CASCADE NOT NULL,
  sender_id       UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  content         TEXT        NOT NULL,
  attachment_urls TEXT[],
  is_admin        BOOLEAN     DEFAULT false,  -- 운영자 답변 여부
  created_at      TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_messages_inquiry ON public.inquiry_messages(inquiry_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON public.inquiry_messages(created_at);

-- RLS 활성화
ALTER TABLE public.inquiry_messages ENABLE ROW LEVEL SECURITY;

-- 해당 문의 작성자 또는 staff만 조회
DROP POLICY IF EXISTS "messages_select" ON public.inquiry_messages;
CREATE POLICY "messages_select"
  ON public.inquiry_messages FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.inquiries
      WHERE id = inquiry_id AND (
        author_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff')
      )
    )
  );

-- 해당 문의 작성자 또는 staff만 메시지 작성
DROP POLICY IF EXISTS "messages_insert" ON public.inquiry_messages;
CREATE POLICY "messages_insert"
  ON public.inquiry_messages FOR INSERT
  TO authenticated
  WITH CHECK (
    sender_id = auth.uid() AND
    EXISTS (
      SELECT 1 FROM public.inquiries
      WHERE id = inquiry_id AND (
        author_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff')
      )
    )
  );


-- ══════════════════════════════════════════════════════════════════
--  vote_count 자동 업데이트 트리거
-- ══════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_vote_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.feedback_posts
    SET vote_count = vote_count + 1
    WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.feedback_posts
    SET vote_count = vote_count - 1
    WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_vote_count ON public.feedback_votes;
CREATE TRIGGER trigger_vote_count
  AFTER INSERT OR DELETE ON public.feedback_votes
  FOR EACH ROW EXECUTE FUNCTION update_vote_count();


-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- 1. 테이블 확인
-- SELECT tablename FROM pg_tables WHERE tablename IN ('feedback_posts', 'feedback_comments', 'feedback_votes', 'inquiries', 'inquiry_messages');

-- 2. RLS 정책 확인
-- SELECT policyname, tablename, cmd FROM pg_policies WHERE tablename LIKE 'feedback%' OR tablename LIKE 'inquir%';

-- ══════════════════════════════════════════════════════════════════
