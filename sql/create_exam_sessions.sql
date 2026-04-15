-- ── 시험 응시 세션 테이블 ──
-- 학생이 온라인으로 시험에 응시할 때 생성되는 세션 기록

-- exams 테이블에 time_limit 컬럼 추가 (분 단위, 기본 60분)
ALTER TABLE exams ADD COLUMN IF NOT EXISTS time_limit INTEGER NOT NULL DEFAULT 60;

-- exam_sessions 테이블 생성
CREATE TABLE IF NOT EXISTS exam_sessions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_id          UUID NOT NULL REFERENCES exams(id) ON DELETE CASCADE,
  student_id       UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  started_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  submitted_at     TIMESTAMPTZ,
  answers          JSONB NOT NULL DEFAULT '{}',
  score            NUMERIC,                        -- NULL = 미공개 또는 미산출
  is_score_published BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(exam_id, student_id)                      -- 재응시 불가
);

-- RLS 활성화
ALTER TABLE exam_sessions ENABLE ROW LEVEL SECURITY;

-- 학생 본인 세션만 읽기/쓰기 가능 (students.email = auth.email 경유)
CREATE POLICY "student_own_session_select"
  ON exam_sessions FOR SELECT
  USING (
    student_id IN (
      SELECT id FROM students WHERE email = auth.jwt() ->> 'email'
    )
  );

CREATE POLICY "student_own_session_insert"
  ON exam_sessions FOR INSERT
  WITH CHECK (
    student_id IN (
      SELECT id FROM students WHERE email = auth.jwt() ->> 'email'
    )
  );

CREATE POLICY "student_own_session_update"
  ON exam_sessions FOR UPDATE
  USING (
    student_id IN (
      SELECT id FROM students WHERE email = auth.jwt() ->> 'email'
    )
  );

-- 선생님은 자기 시험의 세션 모두 읽기/점수 공개 가능
CREATE POLICY "teacher_exam_session_select"
  ON exam_sessions FOR SELECT
  USING (
    exam_id IN (
      SELECT id FROM exams WHERE teacher_id = auth.uid()
    )
  );

CREATE POLICY "teacher_exam_session_update"
  ON exam_sessions FOR UPDATE
  USING (
    exam_id IN (
      SELECT id FROM exams WHERE teacher_id = auth.uid()
    )
  );

-- 인덱스
CREATE INDEX IF NOT EXISTS idx_exam_sessions_exam_id   ON exam_sessions(exam_id);
CREATE INDEX IF NOT EXISTS idx_exam_sessions_student_id ON exam_sessions(student_id);
