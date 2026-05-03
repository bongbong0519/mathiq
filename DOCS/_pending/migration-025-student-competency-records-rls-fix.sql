-- Phase0-Step1 후속: 시험 제출 주체(학생)도 INSERT 가능하도록 RLS 수정

-- 기존 강사 전용 INSERT 정책 제거
DROP POLICY scr_teacher_insert ON student_competency_records;

-- 학생 본인 또는 담당 강사 INSERT 허용
CREATE POLICY scr_insert_by_student_or_teacher ON student_competency_records
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = student_competency_records.student_id
        AND (
          students.user_id = auth.uid()       -- 학생 본인
          OR students.teacher_id = auth.uid() -- 담당 강사
        )
    )
  );
