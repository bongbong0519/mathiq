-- Migration 019: 자료 공유 회수 기능 (소프트 딜리트)
-- 작성일: 2026-05-01
-- 이슈: I-18

-- material_shares 테이블에 revoked_at 칼럼 추가
ALTER TABLE material_shares
ADD COLUMN revoked_at timestamptz NULL;

COMMENT ON COLUMN material_shares.revoked_at IS
'자료 공유 회수 시각. NULL=공유 중, 값 있음=회수됨. 공유한 강사 본인만 회수 가능. 학생/강사 화면에서 모두 숨겨짐.';

-- 부분 인덱스: 활성 공유만 인덱싱 (성능)
CREATE INDEX idx_material_shares_revoked_at
ON material_shares (revoked_at)
WHERE revoked_at IS NULL;

-- ⚠️ RLS 확인 필요:
-- material_shares UPDATE 정책이 "공유한 강사 본인만" 제한되어 있는지 확인.
-- 정책 예시: USING (shared_by = auth.uid())
-- 없으면 추가 필요.
