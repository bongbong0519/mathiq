-- ══════════════════════════════════════
--  patch_roles_and_boards
--  신규 역할(member, expert, staff) 및
--  게시판(admission, math) 추가
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- ─────────────────────────────────────
-- 1. profiles.role CHECK 제약 확장
-- ─────────────────────────────────────
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('teacher', 'director', 'admin', 'student', 'parent', 'member', 'expert', 'staff'));

-- ─────────────────────────────────────
-- 2. posts.board CHECK 제약 확장
--    (기존: notice, student, parent, contact)
-- ─────────────────────────────────────
ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_board_check;
ALTER TABLE public.posts ADD CONSTRAINT posts_board_check
  CHECK (board IN ('notice', 'admission', 'math', 'student', 'parent', 'contact'));

-- ─────────────────────────────────────
-- 3. admission 게시판 RLS
--    읽기: 전체 로그인 사용자
--    쓰기: admin, staff, expert
-- ─────────────────────────────────────
DROP POLICY IF EXISTS "admission_select_auth" ON public.posts;
CREATE POLICY "admission_select_auth"
  ON public.posts FOR SELECT
  TO authenticated
  USING (board = 'admission');

DROP POLICY IF EXISTS "admission_insert_writers" ON public.posts;
CREATE POLICY "admission_insert_writers"
  ON public.posts FOR INSERT
  TO authenticated
  WITH CHECK (
    board = 'admission'
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'staff', 'expert')
  );

DROP POLICY IF EXISTS "admission_update_writers" ON public.posts;
CREATE POLICY "admission_update_writers"
  ON public.posts FOR UPDATE
  TO authenticated
  USING (
    board = 'admission'
    AND (
      author_id = auth.uid()
      OR (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'staff')
    )
  );

DROP POLICY IF EXISTS "admission_delete_writers" ON public.posts;
CREATE POLICY "admission_delete_writers"
  ON public.posts FOR DELETE
  TO authenticated
  USING (
    board = 'admission'
    AND (
      author_id = auth.uid()
      OR (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'staff')
    )
  );

-- ─────────────────────────────────────
-- 4. math 게시판 RLS
--    읽기/쓰기: 전체 로그인 사용자
-- ─────────────────────────────────────
DROP POLICY IF EXISTS "math_select_auth" ON public.posts;
CREATE POLICY "math_select_auth"
  ON public.posts FOR SELECT
  TO authenticated
  USING (board = 'math');

DROP POLICY IF EXISTS "math_insert_auth" ON public.posts;
CREATE POLICY "math_insert_auth"
  ON public.posts FOR INSERT
  TO authenticated
  WITH CHECK (board = 'math' AND author_id = auth.uid());

DROP POLICY IF EXISTS "math_update_auth" ON public.posts;
CREATE POLICY "math_update_auth"
  ON public.posts FOR UPDATE
  TO authenticated
  USING (
    board = 'math'
    AND (
      author_id = auth.uid()
      OR (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'staff')
    )
  );

DROP POLICY IF EXISTS "math_delete_auth" ON public.posts;
CREATE POLICY "math_delete_auth"
  ON public.posts FOR DELETE
  TO authenticated
  USING (
    board = 'math'
    AND (
      author_id = auth.uid()
      OR (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('admin', 'staff')
    )
  );

-- ─────────────────────────────────────
-- 5. math 게시판 댓글 RLS (post_comments)
-- ─────────────────────────────────────
DROP POLICY IF EXISTS "math_comments_select_auth" ON public.post_comments;
CREATE POLICY "math_comments_select_auth"
  ON public.post_comments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_comments.post_id AND posts.board = 'math'
    )
  );

DROP POLICY IF EXISTS "math_comments_insert_auth" ON public.post_comments;
CREATE POLICY "math_comments_insert_auth"
  ON public.post_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_comments.post_id AND posts.board = 'math'
    )
  );

-- ─────────────────────────────────────
-- 6. admission 게시판 댓글 RLS
--    읽기: 로그인 사용자 / 쓰기: 로그인 사용자
-- ─────────────────────────────────────
DROP POLICY IF EXISTS "admission_comments_select_auth" ON public.post_comments;
CREATE POLICY "admission_comments_select_auth"
  ON public.post_comments FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_comments.post_id AND posts.board = 'admission'
    )
  );

DROP POLICY IF EXISTS "admission_comments_insert_auth" ON public.post_comments;
CREATE POLICY "admission_comments_insert_auth"
  ON public.post_comments FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.posts
      WHERE posts.id = post_comments.post_id AND posts.board = 'admission'
    )
  );
