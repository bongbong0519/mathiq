-- ══════════════════════════════════════
--  profiles 테이블 누락 컬럼 추가 패치
--  회원가입 400 오류 원인: organization_id, region, phone, grade 미존재
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone            TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS region           TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS grade            INT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS organization_id  UUID REFERENCES public.organizations(id) ON DELETE SET NULL;

-- profiles INSERT/UPDATE RLS (없으면 추가)
-- 본인 프로필 INSERT 허용
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles' AND policyname = 'profiles_insert_self'
  ) THEN
    CREATE POLICY "profiles_insert_self"
      ON public.profiles FOR INSERT
      TO authenticated
      WITH CHECK (id = auth.uid());
  END IF;
END$$;

-- 본인 프로필 UPDATE 허용
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles' AND policyname = 'profiles_update_self'
  ) THEN
    CREATE POLICY "profiles_update_self"
      ON public.profiles FOR UPDATE
      TO authenticated
      USING (id = auth.uid());
  END IF;
END$$;

-- admin이 모든 프로필 UPDATE 허용 (탈퇴 처리 등)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles' AND policyname = 'profiles_update_admin'
  ) THEN
    CREATE POLICY "profiles_update_admin"
      ON public.profiles FOR UPDATE
      TO authenticated
      USING ((SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin');
  END IF;
END$$;
