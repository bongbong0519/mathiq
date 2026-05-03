-- Phase0-Step1: 6역량 누적 시스템 테이블
-- 학생별 시험 응시당 6역량 raw 데이터 저장, 조회 시점에 SUM 집계

-- 1. 역량 누적 테이블
CREATE TABLE student_competency_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES students(id),
  exam_session_id UUID REFERENCES exam_sessions(id),
  -- 6역량별 earned/total 쌍
  problem_solving_earned NUMERIC NOT NULL DEFAULT 0,
  problem_solving_total NUMERIC NOT NULL DEFAULT 0,
  reasoning_earned NUMERIC NOT NULL DEFAULT 0,
  reasoning_total NUMERIC NOT NULL DEFAULT 0,
  communication_earned NUMERIC NOT NULL DEFAULT 0,
  communication_total NUMERIC NOT NULL DEFAULT 0,
  connection_earned NUMERIC NOT NULL DEFAULT 0,
  connection_total NUMERIC NOT NULL DEFAULT 0,
  info_processing_earned NUMERIC NOT NULL DEFAULT 0,
  info_processing_total NUMERIC NOT NULL DEFAULT 0,
  attitude_earned NUMERIC NOT NULL DEFAULT 0,
  attitude_total NUMERIC NOT NULL DEFAULT 0,
  -- 메타
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- 박제 (C-1 정책)
  student_name_snapshot TEXT,
  student_grade_snapshot TEXT,
  exam_title_snapshot TEXT,
  -- 수정 추적
  modified_at TIMESTAMPTZ,
  modified_by UUID REFERENCES profiles(id),
  modification_reason TEXT,
  UNIQUE(student_id, exam_session_id)
);

CREATE INDEX idx_competency_records_student ON student_competency_records(student_id);
CREATE INDEX idx_competency_records_recorded ON student_competency_records(student_id, recorded_at DESC);

COMMENT ON TABLE student_competency_records IS
'학생별 시험 응시당 6역량 누적 raw 데이터. 조회 시점에 SUM 집계로 평균 산출.';

-- 2. Audit log 테이블
CREATE TABLE competency_modifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  record_id UUID REFERENCES student_competency_records(id),
  modified_by UUID REFERENCES profiles(id),
  modified_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  reason TEXT,
  before_snapshot JSONB,
  after_snapshot JSONB
);

COMMENT ON TABLE competency_modifications IS
'역량 점수 강사 수정 이력. 강사도 삭제 불가, 원장만 조회.';

-- 3. RLS 정책: student_competency_records
ALTER TABLE student_competency_records ENABLE ROW LEVEL SECURITY;

-- 학생 본인 SELECT
CREATE POLICY scr_student_select ON student_competency_records
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = student_competency_records.student_id
        AND students.user_id = auth.uid()
    )
  );

-- 담당 강사 SELECT
CREATE POLICY scr_teacher_select ON student_competency_records
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = student_competency_records.student_id
        AND students.teacher_id = auth.uid()
    )
  );

-- 담당 강사 INSERT (시험 채점 시 자동)
CREATE POLICY scr_teacher_insert ON student_competency_records
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = student_competency_records.student_id
        AND students.teacher_id = auth.uid()
    )
  );

-- 담당 강사 UPDATE (audit log 필수 — 코드에서 강제)
CREATE POLICY scr_teacher_update ON student_competency_records
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = student_competency_records.student_id
        AND students.teacher_id = auth.uid()
    )
  );

-- DELETE 정책 없음 → 삭제 차단

-- 4. RLS 정책: competency_modifications
ALTER TABLE competency_modifications ENABLE ROW LEVEL SECURITY;

-- 원장만 조회
CREATE POLICY cm_admin_select ON competency_modifications
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- 강사 INSERT (자기 학생 수정 시)
CREATE POLICY cm_teacher_insert ON competency_modifications
  FOR INSERT WITH CHECK (modified_by = auth.uid());

-- UPDATE/DELETE 정책 없음 → 변경/삭제 차단
