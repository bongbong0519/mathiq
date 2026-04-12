-- ══════════════════════════════════════
--  posts · post_comments (게시판 엔진)
--  board 종류: notice(입시정보) | student(학생커뮤) | parent(학부모커뮤)
--  ※ 자료실(materials)은 별도 테이블 유지
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.posts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  board TEXT NOT NULL CHECK (board IN ('notice', 'student', 'parent')),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  author_id UUID NOT NULL REFERENCES auth.users(id),
  author_name TEXT,
  author_role TEXT,
  view_count INT DEFAULT 0,
  comment_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_posts_board_created ON public.posts(board, created_at DESC);

CREATE TABLE IF NOT EXISTS public.post_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id),
  author_name TEXT,
  author_role TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_comments_post_created ON public.post_comments(post_id, created_at);

-- ══════════════════════════════════════
--  RLS: posts
-- ══════════════════════════════════════

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- 읽기: notice=전체, student=학생만, parent=학부모만
CREATE POLICY "posts_select"
  ON public.posts FOR SELECT
  TO authenticated
  USING (
    board = 'notice'
    OR (board = 'student' AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'student' AND p.status = 'approved'
    ))
    OR (board = 'parent' AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'parent' AND p.status = 'approved'
    ))
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- 쓰기: notice=admin, student=학생, parent=학부모
CREATE POLICY "posts_insert"
  ON public.posts FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.status = 'approved'
        AND (
          (posts.board = 'notice' AND p.role = 'admin')
          OR (posts.board = 'student' AND p.role = 'student')
          OR (posts.board = 'parent' AND p.role = 'parent')
        )
    )
  );

-- 수정: 본인 또는 admin
CREATE POLICY "posts_update"
  ON public.posts FOR UPDATE
  TO authenticated
  USING (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 삭제: 본인 또는 admin
CREATE POLICY "posts_delete"
  ON public.posts FOR DELETE
  TO authenticated
  USING (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ══════════════════════════════════════
--  RLS: post_comments
-- ══════════════════════════════════════

ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

-- 읽기: 해당 post를 볼 수 있으면 댓글도 볼 수 있음
CREATE POLICY "comments_select"
  ON public.post_comments FOR SELECT
  TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.posts WHERE posts.id = post_comments.post_id)
  );

-- 쓰기: student/parent 게시판만, 본인 역할과 일치하는 게시판에 한해
CREATE POLICY "comments_insert"
  ON public.post_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.posts po
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE po.id = post_comments.post_id
        AND p.status = 'approved'
        AND (
          (po.board = 'student' AND p.role = 'student')
          OR (po.board = 'parent' AND p.role = 'parent')
        )
    )
  );

-- 삭제: 본인 또는 admin
CREATE POLICY "comments_delete"
  ON public.post_comments FOR DELETE
  TO authenticated
  USING (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ══════════════════════════════════════
--  RPC: 조회수 증가
-- ══════════════════════════════════════

CREATE OR REPLACE FUNCTION public.increment_post_view(post_id UUID)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE public.posts SET view_count = view_count + 1 WHERE id = post_id;
$$;

-- ══════════════════════════════════════
--  Trigger: comment_count 자동 갱신
-- ══════════════════════════════════════

CREATE OR REPLACE FUNCTION public.update_post_comment_count()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.posts SET comment_count = GREATEST(comment_count - 1, 0) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_post_comment_count ON public.post_comments;
CREATE TRIGGER trg_post_comment_count
  AFTER INSERT OR DELETE ON public.post_comments
  FOR EACH ROW EXECUTE FUNCTION public.update_post_comment_count();
