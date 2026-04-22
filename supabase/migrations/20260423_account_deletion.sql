-- ══════════════════════════════════════════════════════════════════
--  계정 탈퇴·복구 + 개인정보 동의 시스템
--
--  Supabase 대시보드 > SQL Editor에서 실행
--  실행 순서: 섹션 1 → 2 → 3 → 4 → 5
-- ══════════════════════════════════════════════════════════════════


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 1: profiles 테이블에 soft delete 컬럼 추가                 │
-- └─────────────────────────────────────────────────────────────────┘

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deletion_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_profiles_deleted ON public.profiles(deleted_at)
  WHERE deleted_at IS NOT NULL;


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 2: 탈퇴 시 스냅샷 테이블                                   │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.account_deletions (
  id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  deleted_at            TIMESTAMPTZ DEFAULT NOW(),
  snapshot_point_balance INTEGER    DEFAULT 0,
  snapshot_cash_balance  INTEGER    DEFAULT 0,
  reason                TEXT,
  recovered_at          TIMESTAMPTZ,
  recovery_type         TEXT        CHECK (recovery_type IN ('auto_50', 'admin_100')),
  recovered_points      INTEGER     DEFAULT 0,
  created_at            TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.account_deletions IS '계정 탈퇴 스냅샷 (30일 보관)';
COMMENT ON COLUMN public.account_deletions.recovery_type IS 'auto_50=자동복구(50%), admin_100=운영자승인(100%)';

CREATE INDEX IF NOT EXISTS idx_deletions_user ON public.account_deletions(user_id);
CREATE INDEX IF NOT EXISTS idx_deletions_deleted_at ON public.account_deletions(deleted_at DESC);

ALTER TABLE public.account_deletions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own_deletions" ON public.account_deletions;
CREATE POLICY "own_deletions"
  ON public.account_deletions FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin_user());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 3: 복구 요청 (이의제기) 테이블                             │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.recovery_requests (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  deletion_id   UUID        REFERENCES public.account_deletions(id) ON DELETE CASCADE NOT NULL,
  user_id       UUID        REFERENCES public.profiles(id) NOT NULL,
  message       TEXT,
  status        TEXT        DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  reviewed_by   UUID        REFERENCES public.profiles(id),
  reviewed_at   TIMESTAMPTZ,
  review_note   TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.recovery_requests IS '계정 복구 이의제기 요청';

CREATE INDEX IF NOT EXISTS idx_recovery_user ON public.recovery_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_recovery_status ON public.recovery_requests(status);

ALTER TABLE public.recovery_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own_recovery_requests" ON public.recovery_requests;
CREATE POLICY "own_recovery_requests"
  ON public.recovery_requests FOR ALL
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin_user());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 4: 개인정보 동의 기록 테이블                               │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.privacy_consents (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  consent_type  TEXT        NOT NULL CHECK (consent_type IN ('essential', 'marketing', 'third_party')),
  agreed        BOOLEAN     NOT NULL,
  agreed_at     TIMESTAMPTZ DEFAULT NOW(),
  version       TEXT        DEFAULT 'v1.0'
);

COMMENT ON TABLE public.privacy_consents IS '개인정보 동의 기록';
COMMENT ON COLUMN public.privacy_consents.consent_type IS 'essential=개인정보수집, marketing=마케팅, third_party=이용약관';

CREATE INDEX IF NOT EXISTS idx_consents_user ON public.privacy_consents(user_id);

ALTER TABLE public.privacy_consents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own_consents" ON public.privacy_consents;
CREATE POLICY "own_consents"
  ON public.privacy_consents FOR ALL
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin_user());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 5: 30일 경과 계정 삭제 함수 (수동 실행)                    │
-- └─────────────────────────────────────────────────────────────────┘

CREATE OR REPLACE FUNCTION public.cleanup_expired_accounts()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM auth.users
  WHERE id IN (
    SELECT id FROM public.profiles
    WHERE deleted_at IS NOT NULL
      AND deleted_at < NOW() - INTERVAL '30 days'
  );

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.cleanup_expired_accounts IS '30일 경과 탈퇴 계정 영구 삭제 (수동 실행: SELECT public.cleanup_expired_accounts())';


-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- 1. profiles 컬럼 확인
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'profiles' AND column_name IN ('deleted_at', 'deletion_reason');

-- 2. 테이블 존재 확인
-- SELECT tablename FROM pg_tables
--   WHERE tablename IN ('account_deletions', 'recovery_requests', 'privacy_consents');

-- 3. RLS 정책 확인
-- SELECT policyname, tablename FROM pg_policies
--   WHERE tablename IN ('account_deletions', 'recovery_requests', 'privacy_consents');

-- ══════════════════════════════════════════════════════════════════
