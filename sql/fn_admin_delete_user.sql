-- ══════════════════════════════════════
--  admin_delete_user: auth.users 완전 삭제 함수
--  SECURITY DEFINER로 실행 → postgres 권한으로 auth.users 접근 가능
--  호출: sbClient.rpc('admin_delete_user', { target_user_id: userId })
--  조건: 호출자가 admin 역할이어야 함
-- ══════════════════════════════════════

CREATE OR REPLACE FUNCTION public.admin_delete_user(target_user_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 1. 호출자가 admin인지 확인
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'permission denied: admin only';
  END IF;

  -- 2. post_comments 삭제 (author_id = target, 다른 게시글에 작성한 댓글 포함)
  DELETE FROM public.post_comments WHERE author_id = target_user_id;

  -- 3. posts 삭제 (author_id = target, ON DELETE CASCADE로 해당 글의 댓글도 삭제)
  DELETE FROM public.posts WHERE author_id = target_user_id;

  -- 4. materials 삭제 (uploader_id = target)
  DELETE FROM public.materials WHERE uploader_id = target_user_id;

  -- 5. organizations.owner_id → NULL (nullable FK)
  UPDATE public.organizations SET owner_id = NULL WHERE owner_id = target_user_id;

  -- 6. profiles 삭제
  DELETE FROM public.profiles WHERE id = target_user_id;

  -- 7. auth.users 삭제 (SECURITY DEFINER이므로 postgres 권한으로 접근 가능)
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;

-- 실행 권한: 인증된 사용자만 호출 가능 (내부에서 admin 여부 재확인)
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated;
