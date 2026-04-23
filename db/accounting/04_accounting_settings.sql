-- ══════════════════════════════════════════════════════════════════════════════
-- 04_accounting_settings.sql
-- 회계 설정 테이블 - 강사별 1건
-- Supabase SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. 테이블 생성
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.accounting_settings (
  teacher_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- 현금영수증 설정
  cash_receipt_reminder BOOLEAN DEFAULT TRUE, -- 미발행 알림

  -- 수업료 설정
  material_cost_separated BOOLEAN DEFAULT TRUE,  -- 교재비 별도 관리
  class_based_fee BOOLEAN DEFAULT FALSE,         -- 수업별 과금 (시간제 vs 고정)

  -- 형제 할인 설정
  sibling_discount_enabled BOOLEAN DEFAULT FALSE,
  sibling_discount_rule JSONB DEFAULT '{"type":"percentage","values":[{"count":2,"rate":10},{"count":3,"rate":15}]}'::jsonb,

  -- 등록비 설정
  registration_fee_enabled BOOLEAN DEFAULT FALSE,
  registration_fee_amount INTEGER DEFAULT 0,

  -- 강사 관리 (학원용)
  staff_management_enabled BOOLEAN DEFAULT FALSE,

  -- 위임 결제 설정
  delegation_enabled BOOLEAN DEFAULT FALSE,
  delegation_trigger_days INTEGER DEFAULT 5,    -- N일 연체 시 위임

  -- 기타
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 트리거 연결
-- ─────────────────────────────────────────────────────────────────────────────

DROP TRIGGER IF EXISTS trg_accounting_settings_updated_at ON public.accounting_settings;
CREATE TRIGGER trg_accounting_settings_updated_at
  BEFORE UPDATE ON public.accounting_settings
  FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RLS 활성화 및 정책
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.accounting_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "settings_select_own" ON public.accounting_settings;
CREATE POLICY "settings_select_own" ON public.accounting_settings
  FOR SELECT USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS "settings_insert_own" ON public.accounting_settings;
CREATE POLICY "settings_insert_own" ON public.accounting_settings
  FOR INSERT WITH CHECK (teacher_id = auth.uid());

DROP POLICY IF EXISTS "settings_update_own" ON public.accounting_settings;
CREATE POLICY "settings_update_own" ON public.accounting_settings
  FOR UPDATE USING (teacher_id = auth.uid());

DROP POLICY IF EXISTS "settings_delete_own" ON public.accounting_settings;
CREATE POLICY "settings_delete_own" ON public.accounting_settings
  FOR DELETE USING (teacher_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. 컬럼 코멘트
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON TABLE public.accounting_settings IS '회계 설정 테이블 - 강사별 1건';
COMMENT ON COLUMN public.accounting_settings.cash_receipt_reminder IS '현금영수증 미발행 건 알림 여부';
COMMENT ON COLUMN public.accounting_settings.material_cost_separated IS '교재비 별도 관리 여부';
COMMENT ON COLUMN public.accounting_settings.class_based_fee IS '수업별 과금 여부 (false=월정액)';
COMMENT ON COLUMN public.accounting_settings.sibling_discount_enabled IS '형제 할인 활성화';
COMMENT ON COLUMN public.accounting_settings.sibling_discount_rule IS '형제 할인 규칙 (JSON: type, values[{count, rate}])';
COMMENT ON COLUMN public.accounting_settings.registration_fee_enabled IS '등록비 징수 여부';
COMMENT ON COLUMN public.accounting_settings.registration_fee_amount IS '등록비 금액 (원)';
COMMENT ON COLUMN public.accounting_settings.staff_management_enabled IS '강사 관리 기능 활성화 (학원용)';
COMMENT ON COLUMN public.accounting_settings.delegation_enabled IS '위임 결제(독촉) 기능 활성화';
COMMENT ON COLUMN public.accounting_settings.delegation_trigger_days IS '위임 결제 발동 조건 (연체 N일)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. 기본 설정 자동 생성 함수 (선택적)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_ensure_accounting_settings()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.accounting_settings (teacher_id)
  VALUES (NEW.id)
  ON CONFLICT (teacher_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 선생님/원장님 승인 시 자동 생성 (선택적 - 주석 해제하여 사용)
-- DROP TRIGGER IF EXISTS trg_create_accounting_settings ON public.profiles;
-- CREATE TRIGGER trg_create_accounting_settings
--   AFTER INSERT OR UPDATE OF status ON public.profiles
--   FOR EACH ROW
--   WHEN (NEW.status = 'approved' AND NEW.role IN ('teacher', 'director'))
--   EXECUTE FUNCTION public.fn_ensure_accounting_settings();

-- ─────────────────────────────────────────────────────────────────────────────
-- 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  'accounting_settings' AS table_name,
  COUNT(*) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'accounting_settings';

SELECT
  column_name,
  data_type,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'accounting_settings'
ORDER BY ordinal_position;

SELECT
  policyname,
  cmd
FROM pg_policies
WHERE tablename = 'accounting_settings';
