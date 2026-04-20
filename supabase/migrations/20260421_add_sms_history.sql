-- ══════════════════════════════════════
--  학부모 문자 발송 기능 지원 스키마
--  1. students 테이블에 parent_phone 컬럼 추가
--  2. sms_history 테이블 생성
-- ══════════════════════════════════════

-- ── 1. students 테이블에 학부모 연락처 추가 ──
ALTER TABLE students ADD COLUMN IF NOT EXISTS parent_phone TEXT;
ALTER TABLE students ADD COLUMN IF NOT EXISTS parent_name TEXT;

-- ── 2. sms_history 테이블 생성 ──
CREATE TABLE IF NOT EXISTS sms_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID REFERENCES profiles(id) ON DELETE SET NULL,  -- 보낸 선생님
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,  -- 대상 학생
  recipient_phone TEXT,                                        -- 받을 번호 (학부모)
  message_type TEXT CHECK (message_type IN ('grade', 'attendance', 'homework', 'custom')),
  message_content TEXT,                                        -- 실제 발송될 내용
  related_exam_id UUID REFERENCES exams(id) ON DELETE SET NULL, -- 관련 시험 (성적 통보 시)
  include_report_url BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  scheduled_at TIMESTAMPTZ DEFAULT now(),
  sent_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ── 3. RLS 활성화 ──
ALTER TABLE sms_history ENABLE ROW LEVEL SECURITY;

-- 선생님: 자기가 보낸 문자만 조회/작성
CREATE POLICY "teacher_sms_select"
  ON sms_history FOR SELECT
  USING (sender_id = auth.uid());

CREATE POLICY "teacher_sms_insert"
  ON sms_history FOR INSERT
  WITH CHECK (sender_id = auth.uid());

-- staff(운영자): 전체 조회 가능
CREATE POLICY "staff_sms_select"
  ON sms_history FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'
    )
  );

-- staff: 상태 업데이트 가능 (발송 처리용)
CREATE POLICY "staff_sms_update"
  ON sms_history FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'staff'
    )
  );

-- ── 4. 인덱스 ──
CREATE INDEX IF NOT EXISTS idx_sms_history_sender ON sms_history(sender_id);
CREATE INDEX IF NOT EXISTS idx_sms_history_student ON sms_history(student_id);
CREATE INDEX IF NOT EXISTS idx_sms_history_status ON sms_history(status);
CREATE INDEX IF NOT EXISTS idx_sms_history_created ON sms_history(created_at DESC);
