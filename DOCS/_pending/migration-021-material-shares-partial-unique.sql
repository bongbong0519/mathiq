-- I-18 후속: material_shares UNIQUE 제약을 부분 인덱스로 변경
-- 회수된 행이 남아있어도 동일 (material_id, student_id)로 재공유 가능하도록

-- 1. 기존 UNIQUE 제약 제거
ALTER TABLE material_shares
DROP CONSTRAINT material_shares_material_id_student_id_key;

-- 2. 부분 UNIQUE 인덱스 생성 (활성 공유만 유일성 보장)
CREATE UNIQUE INDEX material_shares_active_unique
ON material_shares (material_id, student_id)
WHERE revoked_at IS NULL;
