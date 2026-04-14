-- ══════════════════════════════════════
--  patch_tutor_public_read
--  과외매칭 LP 페이지 비로그인 조회 허용
--  tutor_profiles / tutee_profiles / profiles(name)
--  public(anon) SELECT 정책 추가
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- tutor_profiles: 비로그인 사용자도 활성 프로필 읽기 가능
DROP POLICY IF EXISTS "tutor_profiles_select_public" ON public.tutor_profiles;
CREATE POLICY "tutor_profiles_select_public"
  ON public.tutor_profiles FOR SELECT
  TO public
  USING (is_active = true);

-- tutee_profiles: 비로그인 사용자도 활성 구인 읽기 가능
DROP POLICY IF EXISTS "tutee_profiles_select_public" ON public.tutee_profiles;
CREATE POLICY "tutee_profiles_select_public"
  ON public.tutee_profiles FOR SELECT
  TO public
  USING (is_active = true);

-- profiles: 이름 표시를 위해 public 읽기 허용
--   (email 등 민감정보도 포함되므로 주의 — 필요시 별도 view 생성 권장)
DROP POLICY IF EXISTS "profiles_select_public" ON public.profiles;
CREATE POLICY "profiles_select_public"
  ON public.profiles FOR SELECT
  TO public
  USING (true);
