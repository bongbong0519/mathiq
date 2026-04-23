-- ══════════════════════════════════════════════════════════════════════════════
-- 20260424_add_calendar_events.sql
-- 대시보드 월간 캘린더용 일정 테이블 신설
-- Supabase SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. calendar_events 테이블 생성
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_date DATE NOT NULL,
  title VARCHAR(100) NOT NULL,
  event_type VARCHAR(20) NOT NULL DEFAULT '기타',
  memo TEXT,
  color VARCHAR(20) DEFAULT '#F59E0B',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CONSTRAINT calendar_events_type_check
    CHECK (event_type IN ('시험', '상담', '수업', '휴일', '기타'))
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 인덱스 생성 (teacher_id + event_date 복합)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_calendar_events_teacher_date
  ON public.calendar_events(teacher_id, event_date);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RLS 활성화 및 정책 설정
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "teachers_own_calendar_select" ON public.calendar_events
  FOR SELECT USING (teacher_id = auth.uid());

CREATE POLICY "teachers_own_calendar_insert" ON public.calendar_events
  FOR INSERT WITH CHECK (teacher_id = auth.uid());

CREATE POLICY "teachers_own_calendar_update" ON public.calendar_events
  FOR UPDATE USING (teacher_id = auth.uid());

CREATE POLICY "teachers_own_calendar_delete" ON public.calendar_events
  FOR DELETE USING (teacher_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. updated_at 자동 갱신 트리거
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_calendar_events_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_calendar_events_updated_at
  BEFORE UPDATE ON public.calendar_events
  FOR EACH ROW
  EXECUTE FUNCTION update_calendar_events_updated_at();

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. 컬럼 코멘트
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON TABLE public.calendar_events IS '대시보드 월간 캘린더 개인 일정';
COMMENT ON COLUMN public.calendar_events.event_type IS '일정 유형: 시험, 상담, 수업, 휴일, 기타';
COMMENT ON COLUMN public.calendar_events.color IS '이벤트 색상 (HEX). 기본값: #F59E0B (주황)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  column_name,
  data_type,
  column_default,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'calendar_events'
ORDER BY ordinal_position;
-- 9개 행 (id, teacher_id, event_date, title, event_type, memo, color, created_at, updated_at)

-- RLS 정책 확인
SELECT policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'calendar_events';
-- 4개 정책 (select, insert, update, delete)
