-- ============================================================
-- MathIQ 테스트 사용자 정리 SQL
-- 작성일: 2026-04-26
-- 목적: 테스트 사용자 18명 삭제 (봉쌤 admin 계정만 보존)
-- ============================================================

-- ■ 보존할 계정 (절대 삭제 금지)
-- UUID: c5a39205-83c8-4ac9-9a09-686e9e7aacc6
-- 이메일: wldbsl1321@naver.com

-- ============================================================
-- PART 0: 외래키 의존성 조회 (실행해서 구조 파악용)
-- ============================================================

-- 0-1. profiles 테이블을 참조하는 모든 외래키 조회
SELECT
    tc.table_name AS 자식테이블,
    kcu.column_name AS 외래키컬럼,
    ccu.table_name AS 부모테이블,
    ccu.column_name AS 참조컬럼,
    rc.delete_rule AS 삭제규칙
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name = 'profiles'
ORDER BY tc.table_name;

-- 0-2. auth.users 테이블을 참조하는 모든 외래키 조회
SELECT
    tc.table_name AS 자식테이블,
    kcu.column_name AS 외래키컬럼,
    ccu.table_name AS 부모테이블,
    ccu.column_name AS 참조컬럼,
    rc.delete_rule AS 삭제규칙
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_schema = 'auth'
    AND ccu.table_name = 'users'
ORDER BY tc.table_name;

-- ============================================================
-- PART 1: 삭제 전 검증 (각 테이블별 삭제될 행 수 확인)
-- ============================================================

-- 봉쌤 admin UUID
-- c5a39205-83c8-4ac9-9a09-686e9e7aacc6

SELECT '=== 삭제 전 행 수 확인 ===' AS 안내;

-- profiles 테이블 (삭제 대상 사용자 수)
SELECT 'profiles' AS 테이블,
       COUNT(*) AS 삭제예정,
       (SELECT COUNT(*) FROM profiles WHERE id = 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6') AS 보존확인
FROM profiles
WHERE id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- 아래 테이블들은 user_id 또는 teacher_id 컬럼으로 연결됨
SELECT 'students' AS 테이블, COUNT(*) AS 삭제예정 FROM students WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'exams' AS 테이블, COUNT(*) AS 삭제예정 FROM exams WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'exam_sessions' AS 테이블, COUNT(*) AS 삭제예정 FROM exam_sessions WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'exam_results' AS 테이블, COUNT(*) AS 삭제예정 FROM exam_results WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'exam_questions' AS 테이블, COUNT(*) AS 삭제예정 FROM exam_questions WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'exam_assignments' AS 테이블, COUNT(*) AS 삭제예정 FROM exam_assignments WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'questions' AS 테이블, COUNT(*) AS 삭제예정 FROM questions WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'calendar_events' AS 테이블, COUNT(*) AS 삭제예정 FROM calendar_events WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'accounting_income' AS 테이블, COUNT(*) AS 삭제예정 FROM accounting_income WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'accounting_expense' AS 테이블, COUNT(*) AS 삭제예정 FROM accounting_expense WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'accounting_staff_salary' AS 테이블, COUNT(*) AS 삭제예정 FROM accounting_staff_salary WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'teacher_payment_settings' AS 테이블, COUNT(*) AS 삭제예정 FROM teacher_payment_settings WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'payment_reminders' AS 테이블, COUNT(*) AS 삭제예정 FROM payment_reminders WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'billing_invoices' AS 테이블, COUNT(*) AS 삭제예정 FROM billing_invoices WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'materials' AS 테이블, COUNT(*) AS 삭제예정 FROM materials WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'class_materials' AS 테이블, COUNT(*) AS 삭제예정 FROM class_materials WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'material_shares' AS 테이블, COUNT(*) AS 삭제예정 FROM material_shares WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'sms_history' AS 테이블, COUNT(*) AS 삭제예정 FROM sms_history WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'academy_staff' AS 테이블, COUNT(*) AS 삭제예정 FROM academy_staff WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'teacher_comments' AS 테이블, COUNT(*) AS 삭제예정 FROM teacher_comments WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- user_id 컬럼 사용 테이블
SELECT 'tutor_profiles' AS 테이블, COUNT(*) AS 삭제예정 FROM tutor_profiles WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'tutee_profiles' AS 테이블, COUNT(*) AS 삭제예정 FROM tutee_profiles WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'tutor_matches' AS 테이블, COUNT(*) AS 삭제예정 FROM tutor_matches WHERE tutor_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' AND tutee_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'tutor_match_requests' AS 테이블, COUNT(*) AS 삭제예정 FROM tutor_match_requests WHERE requester_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- author_id 컬럼 사용 테이블
SELECT 'notices' AS 테이블, COUNT(*) AS 삭제예정 FROM notices WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'posts' AS 테이블, COUNT(*) AS 삭제예정 FROM posts WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'post_comments' AS 테이블, COUNT(*) AS 삭제예정 FROM post_comments WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- 기타 사용자 연결 테이블
SELECT 'notice_reads' AS 테이블, COUNT(*) AS 삭제예정 FROM notice_reads WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'privacy_consents' AS 테이블, COUNT(*) AS 삭제예정 FROM privacy_consents WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'uploaded_files' AS 테이블, COUNT(*) AS 삭제예정 FROM uploaded_files WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'messages' AS 테이블, COUNT(*) AS 삭제예정 FROM messages WHERE sender_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' AND receiver_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'inquiries' AS 테이블, COUNT(*) AS 삭제예정 FROM inquiries WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'inquiry_messages' AS 테이블, COUNT(*) AS 삭제예정 FROM inquiry_messages WHERE sender_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'feedback_posts' AS 테이블, COUNT(*) AS 삭제예정 FROM feedback_posts WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'feedback_comments' AS 테이블, COUNT(*) AS 삭제예정 FROM feedback_comments WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'feedback_votes' AS 테이블, COUNT(*) AS 삭제예정 FROM feedback_votes WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'account_deletions' AS 테이블, COUNT(*) AS 삭제예정 FROM account_deletions WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'recovery_requests' AS 테이블, COUNT(*) AS 삭제예정 FROM recovery_requests WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
SELECT 'organizations' AS 테이블, COUNT(*) AS 삭제예정 FROM organizations WHERE owner_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ============================================================
-- PART 2: 본 삭제 작업 (트랜잭션으로 감싸기)
-- ============================================================
-- ⚠️ 주의: 아래 코드는 PART 1 확인 후 실행할 것!
-- Supabase SQL Editor에서 BEGIN ~ COMMIT 사이만 복사해서 실행

BEGIN;

-- ──────────────────────────────────────────────────────────────
-- STEP 1: 최하위 자식 테이블부터 삭제 (외래키 역순)
-- ──────────────────────────────────────────────────────────────

-- 1-1. 시험 관련 (exam_results → exam_sessions → exam_questions → exam_assignments → exams)
DELETE FROM exam_results WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM exam_sessions WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM exam_questions WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM exam_assignments WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM exams WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- 1-2. 회계 관련
DELETE FROM accounting_staff_salary WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM accounting_income WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM accounting_expense WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM billing_invoices WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM payment_reminders WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM teacher_payment_settings WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- 1-3. 학생 관련
DELETE FROM teacher_comments WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM students WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- 1-4. 자료/문제 관련
DELETE FROM material_shares WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM class_materials WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM materials WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM questions WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- 1-5. 캘린더/SMS
DELETE FROM calendar_events WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM sms_history WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- 1-6. 학원 직원
DELETE FROM academy_staff WHERE teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ──────────────────────────────────────────────────────────────
-- STEP 2: 과외 매칭 관련
-- ──────────────────────────────────────────────────────────────

DELETE FROM tutor_match_requests WHERE requester_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM tutor_matches WHERE tutor_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' AND tutee_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM tutor_profiles WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM tutee_profiles WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ──────────────────────────────────────────────────────────────
-- STEP 3: 게시판/커뮤니티 관련
-- ──────────────────────────────────────────────────────────────

DELETE FROM post_comments WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM posts WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM notice_reads WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM notices WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ──────────────────────────────────────────────────────────────
-- STEP 4: 피드백/문의 관련
-- ──────────────────────────────────────────────────────────────

DELETE FROM feedback_votes WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM feedback_comments WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM feedback_posts WHERE author_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM inquiry_messages WHERE sender_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM inquiries WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ──────────────────────────────────────────────────────────────
-- STEP 5: 기타 사용자 데이터
-- ──────────────────────────────────────────────────────────────

DELETE FROM messages WHERE sender_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' AND receiver_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM privacy_consents WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM uploaded_files WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM account_deletions WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
DELETE FROM recovery_requests WHERE user_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ──────────────────────────────────────────────────────────────
-- STEP 6: 기관 삭제 (profiles 삭제 전에)
-- ──────────────────────────────────────────────────────────────

DELETE FROM organizations WHERE owner_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ──────────────────────────────────────────────────────────────
-- STEP 7: profiles 테이블 삭제 (auth.users 전에)
-- ──────────────────────────────────────────────────────────────

DELETE FROM profiles WHERE id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ──────────────────────────────────────────────────────────────
-- STEP 8: auth.users 삭제 (최종)
-- ⚠️ 주의: auth 스키마 삭제는 service_role 권한 필요!
-- Supabase Dashboard → Authentication → Users에서 수동 삭제하거나
-- 아래 쿼리 사용 (service_role key 필요)
-- ──────────────────────────────────────────────────────────────

-- 옵션 A: SQL로 직접 삭제 (service_role 권한 있을 때)
DELETE FROM auth.users WHERE id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- 옵션 B: 위 쿼리 실패 시 → Dashboard에서 수동 삭제
-- Supabase Dashboard → Authentication → Users → 각 사용자 선택 → Delete

COMMIT;

-- ============================================================
-- PART 3: 삭제 후 검증
-- ============================================================

-- 봉쌤 admin 계정만 남았는지 확인
SELECT '=== 삭제 후 검증 ===' AS 안내;

SELECT 'profiles' AS 테이블, COUNT(*) AS 남은행수,
       CASE WHEN COUNT(*) = 1 THEN '✅ 정상' ELSE '❌ 확인필요' END AS 상태
FROM profiles;

SELECT 'auth.users' AS 테이블, COUNT(*) AS 남은행수,
       CASE WHEN COUNT(*) = 1 THEN '✅ 정상' ELSE '❌ 확인필요' END AS 상태
FROM auth.users;

-- 봉쌤 계정 정보 확인
SELECT id, email, name, role, subscription_tier
FROM profiles
WHERE id = 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ============================================================
-- PART 4: 외래키 목록 (수동 확인용)
-- ============================================================

/*
발견된 외래키 패턴 (코드 분석 기반):

■ teacher_id → profiles.id 참조 테이블들 (약 20개):
  students, exams, exam_sessions, exam_results, exam_questions,
  exam_assignments, questions, calendar_events, accounting_income,
  accounting_expense, accounting_staff_salary, teacher_payment_settings,
  payment_reminders, billing_invoices, materials, class_materials,
  material_shares, sms_history, academy_staff, teacher_comments

■ user_id → profiles.id 또는 auth.users.id 참조:
  tutor_profiles, tutee_profiles, notice_reads, privacy_consents,
  uploaded_files, inquiries, feedback_votes, account_deletions,
  recovery_requests

■ author_id → profiles.id 참조:
  notices, posts, post_comments, feedback_posts, feedback_comments

■ 기타 참조:
  tutor_matches (tutor_id, tutee_id)
  tutor_match_requests (requester_id)
  messages (sender_id, receiver_id)
  inquiry_messages (sender_id)
  organizations (owner_id)

■ CASCADE 적용 권장:
  - 대부분 테이블에 ON DELETE CASCADE 적용 가능
  - 예외: account_deletions, recovery_requests (soft delete 기록 보존 필요)

■ C-1 구현 방향 메모:
  1. 단순 CASCADE 적용이 어려운 이유:
     - account_deletions: 삭제 이력 보존 필요
     - recovery_requests: 복구 요청 이력 보존 필요

  2. 권장 구현:
     - 트랙 A (CASCADE): 대부분 테이블에 적용
     - 트랙 B (RPC): delete_user_permanently(user_id) 함수
       → 위 SQL의 STEP 1~8을 함수로 감싸기
       → account_deletions/recovery_requests는 SET NULL 처리

  3. 30일 자동 삭제 구현:
     - pg_cron으로 매일 실행
     - account_deletions에서 30일 지난 사용자 조회
     - delete_user_permanently() 호출
*/

-- ============================================================
-- 실행 순서 요약
-- ============================================================

/*
1. Supabase Dashboard → SQL Editor 접속
2. PART 0 실행 → 외래키 구조 확인 (참고용)
3. PART 1 실행 → 삭제될 행 수 확인 (안전 체크)
4. PART 2의 BEGIN ~ COMMIT 블록 실행 → 실제 삭제
   ⚠️ auth.users 삭제 실패 시 → Dashboard에서 수동 삭제
5. PART 3 실행 → 봉쌤 계정만 남았는지 검증
*/
