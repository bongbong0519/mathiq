-- ══════════════════════════════════════════════════════════════════
--  수강료 청구 + MathIQ 독촉 시스템
--
--  Supabase 대시보드 > SQL Editor에서 실행
--  실행 순서: 섹션 1 → 2 → 3 → 4 → 5
-- ══════════════════════════════════════════════════════════════════


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 1: students 테이블에 monthly_tuition 컬럼 추가             │
-- └─────────────────────────────────────────────────────────────────┘

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS monthly_tuition INTEGER DEFAULT 0;

COMMENT ON COLUMN public.students.monthly_tuition IS '월 수강료 (원)';


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 2: 선생님 입금 정보 테이블                                  │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.teacher_payment_settings (
  user_id       UUID        PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  bank_name     TEXT,                           -- 은행명
  account_number TEXT,                          -- 계좌번호
  account_holder TEXT,                          -- 예금주
  toss_link     TEXT,                           -- toss.me/xxx (선택)
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.teacher_payment_settings IS '선생님 입금 계좌 정보';

-- RLS
ALTER TABLE public.teacher_payment_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teacher_own_settings" ON public.teacher_payment_settings;
CREATE POLICY "teacher_own_settings"
  ON public.teacher_payment_settings FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- admin 조회
DROP POLICY IF EXISTS "admin_view_settings" ON public.teacher_payment_settings;
CREATE POLICY "admin_view_settings"
  ON public.teacher_payment_settings FOR SELECT
  TO authenticated
  USING (public.is_admin_user());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 3: 청구서 테이블                                           │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.billing_invoices (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id    UUID        REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
  teacher_id    UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  billing_month TEXT        NOT NULL,           -- 'YYYY-MM' 형식
  amount        INTEGER     NOT NULL,           -- 청구 금액 (원)
  sent_at       TIMESTAMPTZ,                    -- 문자 발송 시점
  status        TEXT        DEFAULT 'sent' CHECK (status IN ('sent', 'paid')),
  paid_at       TIMESTAMPTZ,                    -- 납부 확인 시점
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.billing_invoices IS '수강료 청구 기록';

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_invoices_teacher ON public.billing_invoices(teacher_id);
CREATE INDEX IF NOT EXISTS idx_invoices_student ON public.billing_invoices(student_id);
CREATE INDEX IF NOT EXISTS idx_invoices_month ON public.billing_invoices(billing_month);

-- RLS
ALTER TABLE public.billing_invoices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teacher_own_invoices" ON public.billing_invoices;
CREATE POLICY "teacher_own_invoices"
  ON public.billing_invoices FOR ALL
  TO authenticated
  USING (teacher_id = auth.uid())
  WITH CHECK (teacher_id = auth.uid());

-- admin 전체 조회
DROP POLICY IF EXISTS "admin_view_invoices" ON public.billing_invoices;
CREATE POLICY "admin_view_invoices"
  ON public.billing_invoices FOR SELECT
  TO authenticated
  USING (public.is_admin_user());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 4: MathIQ 독촉 기록 테이블                                  │
-- └─────────────────────────────────────────────────────────────────┘

CREATE TABLE IF NOT EXISTS public.payment_reminders (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id        UUID        REFERENCES public.students(id) ON DELETE CASCADE NOT NULL,
  teacher_id        UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  billing_month     TEXT        NOT NULL,       -- 'YYYY-MM'
  amount            INTEGER     NOT NULL,       -- 금액
  requested_at      TIMESTAMPTZ DEFAULT NOW(),  -- 선생님 요청 시점
  sent_at           TIMESTAMPTZ,                -- 실제 발송 시점
  parent_replied_at TIMESTAMPTZ,                -- 학부모 답장 시점
  parent_reply_body TEXT,                       -- 학부모 답장 내용
  status            TEXT        DEFAULT 'sent' CHECK (status IN ('sent', 'parent_replied', 'resolved')),
  resolved_at       TIMESTAMPTZ,                -- 해결 처리 시점
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE public.payment_reminders IS 'MathIQ 독촉 문자 발송 기록';

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_reminders_teacher ON public.payment_reminders(teacher_id);
CREATE INDEX IF NOT EXISTS idx_reminders_student ON public.payment_reminders(student_id);
CREATE INDEX IF NOT EXISTS idx_reminders_status ON public.payment_reminders(status);
CREATE INDEX IF NOT EXISTS idx_reminders_created ON public.payment_reminders(created_at DESC);

-- RLS
ALTER TABLE public.payment_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teacher_own_reminders" ON public.payment_reminders;
CREATE POLICY "teacher_own_reminders"
  ON public.payment_reminders FOR ALL
  TO authenticated
  USING (teacher_id = auth.uid())
  WITH CHECK (teacher_id = auth.uid());

-- admin 전체 관리
DROP POLICY IF EXISTS "admin_manage_reminders" ON public.payment_reminders;
CREATE POLICY "admin_manage_reminders"
  ON public.payment_reminders FOR ALL
  TO authenticated
  USING (public.is_admin_user());


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 5: updated_at 자동 갱신 트리거                             │
-- └─────────────────────────────────────────────────────────────────┘

-- teacher_payment_settings용 트리거
CREATE OR REPLACE FUNCTION update_teacher_payment_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_payment_settings_updated_at ON public.teacher_payment_settings;
CREATE TRIGGER trigger_payment_settings_updated_at
  BEFORE UPDATE ON public.teacher_payment_settings
  FOR EACH ROW EXECUTE FUNCTION update_teacher_payment_settings_updated_at();


-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- 1. students.monthly_tuition 컬럼 확인
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'students' AND column_name = 'monthly_tuition';

-- 2. 테이블 존재 확인
-- SELECT tablename FROM pg_tables
--   WHERE tablename IN ('teacher_payment_settings', 'billing_invoices', 'payment_reminders');

-- 3. RLS 정책 확인
-- SELECT policyname, tablename FROM pg_policies
--   WHERE tablename IN ('teacher_payment_settings', 'billing_invoices', 'payment_reminders');

-- ══════════════════════════════════════════════════════════════════
