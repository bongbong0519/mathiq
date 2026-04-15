-- ── students 테이블 user_id 컬럼 추가 + exam RLS 재작성 ──
-- 문제: exam_sessions RLS가 auth.jwt()->>'email' 방식이라 403 반환
-- 해결: ① students.user_id(= auth.uid()) 컬럼 추가
--       ② RLS 정책을 profiles 경유 또는 user_id 직접 비교로 교체
--       ③ exam_assignments 학생 SELECT 권한 추가

-- ── 1. students 테이블에 user_id 추가 ──
ALTER TABLE students
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_students_user_id ON students(user_id);

-- ── 2. 기존 학생 레코드에 user_id 채우기 (profiles.email 경유) ──
-- profiles 테이블에 email 컬럼이 있는 경우 자동 매핑
UPDATE students s
SET user_id = p.id
FROM profiles p
WHERE lower(p.email) = lower(s.email)
  AND s.user_id IS NULL;

-- ※ 위 UPDATE로 매핑 안 된 학생은 아래 패턴으로 수동 설정:
-- UPDATE students SET user_id = '<auth_user_id>' WHERE email = 'student@example.com';

-- ── 3. exam_sessions RLS 정책 재작성 ──
-- 기존 이메일 기반 정책 삭제
DROP POLICY IF EXISTS "student_own_session_select" ON exam_sessions;
DROP POLICY IF EXISTS "student_own_session_insert" ON exam_sessions;
DROP POLICY IF EXISTS "student_own_session_update" ON exam_sessions;
DROP POLICY IF EXISTS "teacher_exam_session_select" ON exam_sessions;
DROP POLICY IF EXISTS "teacher_exam_session_update" ON exam_sessions;

-- 학생: user_id 직접 비교 (user_id 있을 때) + profiles 경유 fallback
CREATE POLICY "student_session_select"
  ON exam_sessions FOR SELECT
  USING (
    student_id IN (
      SELECT id FROM students
      WHERE user_id = auth.uid()
         OR id IN (
           SELECT s2.id FROM students s2
           JOIN profiles p ON lower(p.email) = lower(s2.email)
           WHERE p.id = auth.uid()
         )
    )
  );

CREATE POLICY "student_session_insert"
  ON exam_sessions FOR INSERT
  WITH CHECK (
    student_id IN (
      SELECT id FROM students
      WHERE user_id = auth.uid()
         OR id IN (
           SELECT s2.id FROM students s2
           JOIN profiles p ON lower(p.email) = lower(s2.email)
           WHERE p.id = auth.uid()
         )
    )
  );

CREATE POLICY "student_session_update"
  ON exam_sessions FOR UPDATE
  USING (
    student_id IN (
      SELECT id FROM students
      WHERE user_id = auth.uid()
         OR id IN (
           SELECT s2.id FROM students s2
           JOIN profiles p ON lower(p.email) = lower(s2.email)
           WHERE p.id = auth.uid()
         )
    )
  );

-- 선생님: 자기 시험 세션 읽기/수정
CREATE POLICY "teacher_session_select"
  ON exam_sessions FOR SELECT
  USING (
    exam_id IN (SELECT id FROM exams WHERE teacher_id = auth.uid())
  );

CREATE POLICY "teacher_session_update"
  ON exam_sessions FOR UPDATE
  USING (
    exam_id IN (SELECT id FROM exams WHERE teacher_id = auth.uid())
  );

-- ── 4. exam_assignments 학생 SELECT 권한 추가 ──
-- (현재 학생이 자기 배정 목록을 읽지 못하면 시험 목록이 빈 상태로 표시됨)
ALTER TABLE exam_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "student_read_own_assignments" ON exam_assignments;
CREATE POLICY "student_read_own_assignments"
  ON exam_assignments FOR SELECT
  USING (
    student_id IN (
      SELECT id FROM students
      WHERE user_id = auth.uid()
         OR id IN (
           SELECT s2.id FROM students s2
           JOIN profiles p ON lower(p.email) = lower(s2.email)
           WHERE p.id = auth.uid()
         )
    )
  );

-- 선생님: 자기 시험 배정 전체 관리
DROP POLICY IF EXISTS "teacher_manage_assignments" ON exam_assignments;
CREATE POLICY "teacher_manage_assignments"
  ON exam_assignments FOR ALL
  USING (
    exam_id IN (SELECT id FROM exams WHERE teacher_id = auth.uid())
  );
