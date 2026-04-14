-- ══════════════════════════════════════
--  create_tutor_tables
--  과외매칭 테이블 생성
--  tutor_profiles (선생님 과외 프로필)
--  tutee_profiles (학생/학부모 구인 프로필)
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- ─────────────────────────────────────
-- 1. tutor_profiles (선생님 과외 프로필)
-- ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tutor_profiles (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  subject       TEXT,
  region        TEXT,
  hourly_rate   INTEGER,
  education     TEXT,
  experience    TEXT,
  teaching_mode TEXT        CHECK (teaching_mode IN ('online', 'offline', 'both')),
  intro         TEXT,
  is_active     BOOLEAN     DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.tutor_profiles ENABLE ROW LEVEL SECURITY;

-- 활성화된 프로필은 로그인 사용자 모두 읽기 가능
CREATE POLICY "tutor_profiles_select_auth"
  ON public.tutor_profiles FOR SELECT
  TO authenticated
  USING (is_active = true OR user_id = auth.uid());

-- 본인 프로필만 작성/수정
CREATE POLICY "tutor_profiles_insert_own"
  ON public.tutor_profiles FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "tutor_profiles_update_own"
  ON public.tutor_profiles FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "tutor_profiles_delete_own"
  ON public.tutor_profiles FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ─────────────────────────────────────
-- 2. tutee_profiles (학생/학부모 구인 프로필)
-- ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tutee_profiles (
  id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
  subject       TEXT,
  region        TEXT,
  desired_rate  INTEGER,
  grade         TEXT,
  teaching_mode TEXT        CHECK (teaching_mode IN ('online', 'offline', 'both')),
  intro         TEXT,
  is_active     BOOLEAN     DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT now() NOT NULL,
  updated_at    TIMESTAMPTZ DEFAULT now() NOT NULL
);

ALTER TABLE public.tutee_profiles ENABLE ROW LEVEL SECURITY;

-- 활성화된 구인은 로그인 사용자 모두 읽기 가능
CREATE POLICY "tutee_profiles_select_auth"
  ON public.tutee_profiles FOR SELECT
  TO authenticated
  USING (is_active = true OR user_id = auth.uid());

-- 본인 프로필만 작성/수정
CREATE POLICY "tutee_profiles_insert_own"
  ON public.tutee_profiles FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "tutee_profiles_update_own"
  ON public.tutee_profiles FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "tutee_profiles_delete_own"
  ON public.tutee_profiles FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ─────────────────────────────────────
-- 3. profiles 테이블 JOIN 허용 확인
--    tutor_profiles → profiles (name, email 조회용)
--    profiles 테이블에 authenticated SELECT 정책이 있어야 JOIN 가능
-- ─────────────────────────────────────
-- (이미 정책이 있는 경우 무시됨)
DROP POLICY IF EXISTS "profiles_select_auth" ON public.profiles;
CREATE POLICY "profiles_select_auth"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);
