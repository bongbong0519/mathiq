-- 5역량 전환: attitude 칼럼 제거 (2022 개정 교육과정 반영)
-- 2026-05-14 결정: 6역량(2015 개정) → 5역량(2022 개정)
-- 제거: 태도 및 실천 (attitude)

ALTER TABLE student_competency_records
  DROP COLUMN IF EXISTS attitude_earned,
  DROP COLUMN IF EXISTS attitude_total;

COMMENT ON TABLE student_competency_records IS
'학생별 시험 응시당 5역량 누적 raw 데이터. 조회 시점에 SUM 집계로 평균 산출.
5역량: 문제해결, 추론, 의사소통, 연결, 정보처리 (2022 개정 교육과정)';
