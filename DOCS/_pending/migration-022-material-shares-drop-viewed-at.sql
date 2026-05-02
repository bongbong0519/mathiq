-- I-23 마무리: viewed_at 칼럼 제거
-- 미리보기 기능을 Chrome 정책 이슈로 폐기 + 안 읽음 탭 제거로 viewed_at 의미 사라짐
ALTER TABLE material_shares DROP COLUMN viewed_at;
