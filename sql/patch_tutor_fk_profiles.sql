-- ══════════════════════════════════════
--  patch_tutor_fk_profiles
--  tutor_profiles / tutee_profiles 의
--  user_id FK를 auth.users → public.profiles 로 변경
--  Supabase PostgREST 자동 JOIN 지원을 위해 필요
--  (create_tutor_tables.sql 실행 후 이 파일 실행)
-- ══════════════════════════════════════

-- tutor_profiles
ALTER TABLE public.tutor_profiles
  DROP CONSTRAINT IF EXISTS tutor_profiles_user_id_fkey;

ALTER TABLE public.tutor_profiles
  ADD CONSTRAINT tutor_profiles_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- tutee_profiles
ALTER TABLE public.tutee_profiles
  DROP CONSTRAINT IF EXISTS tutee_profiles_user_id_fkey;

ALTER TABLE public.tutee_profiles
  ADD CONSTRAINT tutee_profiles_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
