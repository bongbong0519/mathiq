-- Migration 018: 성적 리포트 강사 연락처 공개 설정
-- 작성일: 2026-05-01
-- 이슈: I-17

-- profiles 테이블에 report_contact_visible 칼럼 추가
ALTER TABLE profiles
ADD COLUMN report_contact_visible boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN profiles.report_contact_visible IS
'성적 리포트/학생 대시보드에서 이메일/전화 공개 여부. false=이름만, true=이름+이메일+전화. 강사 본인만 수정 가능.';

-- RLS 변경 불필요 (기존 RLS로 본인만 자기 row UPDATE 가능)
