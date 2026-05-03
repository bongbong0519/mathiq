-- I-22 RLS 보강: 강사 ALL 정책 → SELECT/INSERT 분리, UPDATE/DELETE 차단

DROP POLICY IF EXISTS teacher_own_comments ON teacher_comments;

CREATE POLICY teacher_select_comments ON teacher_comments
  FOR SELECT
  USING (teacher_id = auth.uid());

CREATE POLICY teacher_insert_comments ON teacher_comments
  FOR INSERT
  WITH CHECK (
    teacher_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM students
      WHERE students.id = teacher_comments.student_id
        AND students.teacher_id = auth.uid()
    )
  );

-- UPDATE/DELETE 정책은 만들지 않음 → RLS deny by default로 차단
