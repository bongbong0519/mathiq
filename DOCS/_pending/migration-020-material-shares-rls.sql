-- I-18 material_shares RLS 보강
-- 작성일: 2026-05-01
-- 목적:
--   1) 강사 UPDATE 정책 추가 (회수 기능 작동을 위해)
--   2) 학생 UPDATE 정책 재생성 (revoked_at 보호)

-- 1. 강사 UPDATE 정책 추가
CREATE POLICY shares_teacher_update ON material_shares
  FOR UPDATE
  USING (shared_by = auth.uid())
  WITH CHECK (shared_by = auth.uid());

-- 2. 학생 UPDATE 정책 재생성
DROP POLICY shares_student_update ON material_shares;

CREATE POLICY shares_student_update ON material_shares
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = material_shares.student_id
        AND students.user_id = auth.uid()
    )
    AND revoked_at IS NULL
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM students
      WHERE students.id = material_shares.student_id
        AND students.user_id = auth.uid()
    )
    AND revoked_at IS NULL
  );

-- 작동 원리:
-- - 학생이 viewed_at/downloaded_at 찍기 (정상 자료): 통과
-- - 학생이 회수된 자료의 revoked_at을 NULL로 되돌리기 시도: USING에서 차단
-- - 학생이 정상 자료의 revoked_at을 값으로 바꾸기 시도: WITH CHECK에서 차단
-- - 강사가 자기가 공유한 행에 revoked_at 설정: 통과 (회수 작동)
