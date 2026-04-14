-- ══════════════════════════════════════
--  patch_contact_board: 문의하기 게시판 지원
--  posts 테이블에 contact board 추가
--  비회원 작성, 운영자 답변 지원
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- 1. board CHECK 제약에 'contact' 추가
ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_board_check;
ALTER TABLE public.posts ADD CONSTRAINT posts_board_check
  CHECK (board IN ('notice', 'student', 'parent', 'contact'));

-- 2. author_id nullable 허용 (비회원 문의용)
ALTER TABLE public.posts ALTER COLUMN author_id DROP NOT NULL;

-- 3. 문의 전용 컬럼 추가
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT false;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS guest_name   TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS guest_email  TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_replied   BOOLEAN DEFAULT false;

-- 4. RLS: contact 게시판 공개 읽기 (비로그인 포함)
DROP POLICY IF EXISTS "contact_select_public" ON public.posts;
CREATE POLICY "contact_select_public"
  ON public.posts FOR SELECT
  TO public
  USING (board = 'contact');

-- 5. RLS: contact 게시판 공개 작성 (비로그인 포함)
DROP POLICY IF EXISTS "contact_insert_public" ON public.posts;
CREATE POLICY "contact_insert_public"
  ON public.posts FOR INSERT
  TO public
  WITH CHECK (board = 'contact');

-- 6. RLS: contact 게시판 수정 admin만 (is_replied 업데이트용)
DROP POLICY IF EXISTS "contact_update_admin" ON public.posts;
CREATE POLICY "contact_update_admin"
  ON public.posts FOR UPDATE
  TO authenticated
  USING (
    board = 'contact'
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 7. RLS: contact 게시판 삭제 admin만
DROP POLICY IF EXISTS "contact_delete_admin" ON public.posts;
CREATE POLICY "contact_delete_admin"
  ON public.posts FOR DELETE
  TO authenticated
  USING (
    board = 'contact'
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 8. post_comments: contact 게시글 댓글 공개 읽기 (답변 조회)
DROP POLICY IF EXISTS "contact_comments_select_public" ON public.post_comments;
CREATE POLICY "contact_comments_select_public"
  ON public.post_comments FOR SELECT
  TO public
  USING (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_comments.post_id AND posts.board = 'contact'
    )
  );

-- 9. post_comments: contact 게시글 댓글 admin만 작성 (답변)
DROP POLICY IF EXISTS "contact_comments_insert_admin" ON public.post_comments;
CREATE POLICY "contact_comments_insert_admin"
  ON public.post_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    AND EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_comments.post_id AND posts.board = 'contact'
    )
  );
