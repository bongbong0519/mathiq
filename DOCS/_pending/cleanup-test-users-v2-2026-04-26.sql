-- ============================================================
-- MathIQ 테스트 사용자 정리 SQL (v2 - 스키마 검증 강화)
-- 작성일: 2026-04-27
-- 목적: 테스트 사용자 삭제 (봉쌤 admin 계정만 보존)
-- 변경: v1의 컬럼명 추측 오류 수정, 스키마 조회 후 실행
-- ============================================================

-- ■ 보존할 계정 (절대 삭제 금지)
-- UUID: c5a39205-83c8-4ac9-9a09-686e9e7aacc6
-- 이메일: wldbsl1321@naver.com

-- ============================================================
-- STEP 0: 실제 스키마 조회 (필수! 먼저 실행)
-- ============================================================

-- 0-1. profiles를 참조하는 모든 외래키 조회
SELECT
    tc.table_schema,
    tc.table_name AS 자식테이블,
    kcu.column_name AS FK컬럼,
    ccu.table_name AS 부모테이블,
    ccu.column_name AS 참조컬럼,
    rc.delete_rule AS 삭제규칙
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name = 'profiles'
ORDER BY tc.table_name;

-- 0-2. auth.users를 참조하는 모든 외래키 조회
SELECT
    tc.table_schema,
    tc.table_name AS 자식테이블,
    kcu.column_name AS FK컬럼,
    ccu.table_name AS 부모테이블,
    ccu.column_name AS 참조컬럼,
    rc.delete_rule AS 삭제규칙
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_schema = 'auth'
    AND ccu.table_name = 'users'
ORDER BY tc.table_name;

-- 0-3. 모든 테이블과 UUID 타입 컬럼 조회 (사용자 참조 가능성 있는 컬럼)
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND data_type = 'uuid'
ORDER BY table_name, column_name;

-- ============================================================
-- STEP 1: 테이블별 실제 컬럼 확인 (오류났던 테이블들)
-- ============================================================

-- tutor_matches 테이블 컬럼 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'tutor_matches' AND table_schema = 'public';

-- tutor_match_requests 테이블 컬럼 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'tutor_match_requests' AND table_schema = 'public';

-- messages 테이블 컬럼 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'messages' AND table_schema = 'public';

-- organizations 테이블 컬럼 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'organizations' AND table_schema = 'public';

-- feedback 관련 테이블 컬럼 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('feedback_posts', 'feedback_comments', 'feedback_votes')
AND table_schema = 'public';

-- account_deletions 테이블 컬럼 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'account_deletions' AND table_schema = 'public';

-- recovery_requests 테이블 컬럼 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'recovery_requests' AND table_schema = 'public';

-- inquiries 관련 테이블 컬럼 확인
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('inquiries', 'inquiry_messages')
AND table_schema = 'public';

-- ============================================================
-- ⚠️ 위 STEP 0, 1 결과 확인 후 아래 실행!
-- 결과를 봉쌤이 확인하고, 필요시 컬럼명 수정 후 진행
-- ============================================================


-- ============================================================
-- STEP 2: 삭제 전 검증 (안전 버전 - 존재하는 테이블/컬럼만)
-- ============================================================

-- 봉쌤 admin UUID
DO $$
DECLARE
    admin_id UUID := 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
BEGIN
    RAISE NOTICE '=== 삭제 전 검증 시작 ===';
    RAISE NOTICE 'Admin UUID: %', admin_id;
END $$;

-- 확실한 테이블들만 먼저 카운트 (teacher_id 컬럼 확정)
SELECT 'profiles' AS 테이블, COUNT(*) AS 총행수,
       SUM(CASE WHEN id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' THEN 1 ELSE 0 END) AS 삭제예정
FROM profiles;

SELECT 'students' AS 테이블, COUNT(*) AS 총행수,
       SUM(CASE WHEN teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' THEN 1 ELSE 0 END) AS 삭제예정
FROM students;

SELECT 'exams' AS 테이블, COUNT(*) AS 총행수,
       SUM(CASE WHEN teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' THEN 1 ELSE 0 END) AS 삭제예정
FROM exams;

SELECT 'questions' AS 테이블, COUNT(*) AS 총행수,
       SUM(CASE WHEN teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' THEN 1 ELSE 0 END) AS 삭제예정
FROM questions;

SELECT 'calendar_events' AS 테이블, COUNT(*) AS 총행수,
       SUM(CASE WHEN teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' THEN 1 ELSE 0 END) AS 삭제예정
FROM calendar_events;

SELECT 'accounting_income' AS 테이블, COUNT(*) AS 총행수,
       SUM(CASE WHEN teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' THEN 1 ELSE 0 END) AS 삭제예정
FROM accounting_income;

SELECT 'accounting_expense' AS 테이블, COUNT(*) AS 총행수,
       SUM(CASE WHEN teacher_id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6' THEN 1 ELSE 0 END) AS 삭제예정
FROM accounting_expense;

-- ============================================================
-- STEP 3: 안전한 삭제 (DO 블록으로 에러 핸들링)
-- ============================================================

-- ⚠️ STEP 0, 1 결과 확인 후 아래 컬럼명 수정 필요!
-- 아래는 코드 분석 기반 추정 + 에러 핸들링 추가

DO $$
DECLARE
    admin_id UUID := 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
    deleted_count INTEGER;
BEGIN
    RAISE NOTICE '=== 테스트 사용자 삭제 시작 ===';

    -- ────────────────────────────────────────────────────────
    -- GROUP 1: teacher_id 컬럼 사용 테이블 (확실)
    -- ────────────────────────────────────────────────────────

    -- exam_results
    BEGIN
        DELETE FROM exam_results WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'exam_results: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'exam_results: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'exam_results: 테이블 없음, 스킵';
    END;

    -- exam_sessions
    BEGIN
        DELETE FROM exam_sessions WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'exam_sessions: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'exam_sessions: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'exam_sessions: 테이블 없음, 스킵';
    END;

    -- exam_questions
    BEGIN
        DELETE FROM exam_questions WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'exam_questions: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'exam_questions: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'exam_questions: 테이블 없음, 스킵';
    END;

    -- exam_assignments
    BEGIN
        DELETE FROM exam_assignments WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'exam_assignments: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'exam_assignments: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'exam_assignments: 테이블 없음, 스킵';
    END;

    -- exams
    BEGIN
        DELETE FROM exams WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'exams: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'exams: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'exams: 테이블 없음, 스킵';
    END;

    -- accounting_staff_salary
    BEGIN
        DELETE FROM accounting_staff_salary WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'accounting_staff_salary: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'accounting_staff_salary: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'accounting_staff_salary: 테이블 없음, 스킵';
    END;

    -- accounting_income
    BEGIN
        DELETE FROM accounting_income WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'accounting_income: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'accounting_income: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'accounting_income: 테이블 없음, 스킵';
    END;

    -- accounting_expense
    BEGIN
        DELETE FROM accounting_expense WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'accounting_expense: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'accounting_expense: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'accounting_expense: 테이블 없음, 스킵';
    END;

    -- billing_invoices
    BEGIN
        DELETE FROM billing_invoices WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'billing_invoices: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'billing_invoices: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'billing_invoices: 테이블 없음, 스킵';
    END;

    -- payment_reminders
    BEGIN
        DELETE FROM payment_reminders WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'payment_reminders: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'payment_reminders: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'payment_reminders: 테이블 없음, 스킵';
    END;

    -- teacher_payment_settings
    BEGIN
        DELETE FROM teacher_payment_settings WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'teacher_payment_settings: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'teacher_payment_settings: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'teacher_payment_settings: 테이블 없음, 스킵';
    END;

    -- teacher_comments
    BEGIN
        DELETE FROM teacher_comments WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'teacher_comments: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'teacher_comments: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'teacher_comments: 테이블 없음, 스킵';
    END;

    -- students
    BEGIN
        DELETE FROM students WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'students: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'students: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'students: 테이블 없음, 스킵';
    END;

    -- material_shares
    BEGIN
        DELETE FROM material_shares WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'material_shares: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'material_shares: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'material_shares: 테이블 없음, 스킵';
    END;

    -- class_materials
    BEGIN
        DELETE FROM class_materials WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'class_materials: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'class_materials: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'class_materials: 테이블 없음, 스킵';
    END;

    -- materials
    BEGIN
        DELETE FROM materials WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'materials: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'materials: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'materials: 테이블 없음, 스킵';
    END;

    -- questions
    BEGIN
        DELETE FROM questions WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'questions: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'questions: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'questions: 테이블 없음, 스킵';
    END;

    -- calendar_events
    BEGIN
        DELETE FROM calendar_events WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'calendar_events: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'calendar_events: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'calendar_events: 테이블 없음, 스킵';
    END;

    -- sms_history
    BEGIN
        DELETE FROM sms_history WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'sms_history: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'sms_history: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'sms_history: 테이블 없음, 스킵';
    END;

    -- academy_staff
    BEGIN
        DELETE FROM academy_staff WHERE teacher_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'academy_staff: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'academy_staff: teacher_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'academy_staff: 테이블 없음, 스킵';
    END;

    -- ────────────────────────────────────────────────────────
    -- GROUP 2: user_id 컬럼 사용 테이블
    -- ────────────────────────────────────────────────────────

    -- tutor_profiles
    BEGIN
        DELETE FROM tutor_profiles WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'tutor_profiles: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'tutor_profiles: user_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'tutor_profiles: 테이블 없음, 스킵';
    END;

    -- tutee_profiles
    BEGIN
        DELETE FROM tutee_profiles WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'tutee_profiles: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'tutee_profiles: user_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'tutee_profiles: 테이블 없음, 스킵';
    END;

    -- tutor_match_requests (컬럼명 불확실)
    BEGIN
        DELETE FROM tutor_match_requests WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'tutor_match_requests (user_id): % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        -- 다른 컬럼명 시도
        BEGIN
            DELETE FROM tutor_match_requests WHERE requester_id != admin_id;
            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            RAISE NOTICE 'tutor_match_requests (requester_id): % rows deleted', deleted_count;
        EXCEPTION WHEN undefined_column THEN
            RAISE NOTICE 'tutor_match_requests: user_id/requester_id 컬럼 없음, 스킵';
        END;
    WHEN undefined_table THEN
        RAISE NOTICE 'tutor_match_requests: 테이블 없음, 스킵';
    END;

    -- tutor_matches (컬럼명 불확실 - tutor_id만 있을 수 있음)
    BEGIN
        DELETE FROM tutor_matches WHERE tutor_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'tutor_matches (tutor_id): % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'tutor_matches: tutor_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'tutor_matches: 테이블 없음, 스킵';
    END;

    -- notice_reads
    BEGIN
        DELETE FROM notice_reads WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'notice_reads: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'notice_reads: user_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'notice_reads: 테이블 없음, 스킵';
    END;

    -- privacy_consents
    BEGIN
        DELETE FROM privacy_consents WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'privacy_consents: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'privacy_consents: user_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'privacy_consents: 테이블 없음, 스킵';
    END;

    -- uploaded_files
    BEGIN
        DELETE FROM uploaded_files WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'uploaded_files: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'uploaded_files: user_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'uploaded_files: 테이블 없음, 스킵';
    END;

    -- ────────────────────────────────────────────────────────
    -- GROUP 3: author_id 컬럼 사용 테이블
    -- ────────────────────────────────────────────────────────

    -- post_comments
    BEGIN
        DELETE FROM post_comments WHERE author_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'post_comments: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'post_comments: author_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'post_comments: 테이블 없음, 스킵';
    END;

    -- posts
    BEGIN
        DELETE FROM posts WHERE author_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'posts: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'posts: author_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'posts: 테이블 없음, 스킵';
    END;

    -- notices
    BEGIN
        DELETE FROM notices WHERE author_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'notices: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'notices: author_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'notices: 테이블 없음, 스킵';
    END;

    -- ────────────────────────────────────────────────────────
    -- GROUP 4: 기타 테이블 (컬럼명 불확실)
    -- ────────────────────────────────────────────────────────

    -- feedback_votes
    BEGIN
        DELETE FROM feedback_votes WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'feedback_votes: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'feedback_votes: user_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'feedback_votes: 테이블 없음, 스킵';
    END;

    -- feedback_comments
    BEGIN
        DELETE FROM feedback_comments WHERE author_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'feedback_comments: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        -- user_id 시도
        BEGIN
            DELETE FROM feedback_comments WHERE user_id != admin_id;
            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            RAISE NOTICE 'feedback_comments (user_id): % rows deleted', deleted_count;
        EXCEPTION WHEN undefined_column THEN
            RAISE NOTICE 'feedback_comments: author_id/user_id 컬럼 없음, 스킵';
        END;
    WHEN undefined_table THEN
        RAISE NOTICE 'feedback_comments: 테이블 없음, 스킵';
    END;

    -- feedback_posts
    BEGIN
        DELETE FROM feedback_posts WHERE author_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'feedback_posts: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        -- user_id 시도
        BEGIN
            DELETE FROM feedback_posts WHERE user_id != admin_id;
            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            RAISE NOTICE 'feedback_posts (user_id): % rows deleted', deleted_count;
        EXCEPTION WHEN undefined_column THEN
            RAISE NOTICE 'feedback_posts: author_id/user_id 컬럼 없음, 스킵';
        END;
    WHEN undefined_table THEN
        RAISE NOTICE 'feedback_posts: 테이블 없음, 스킵';
    END;

    -- inquiry_messages
    BEGIN
        DELETE FROM inquiry_messages WHERE sender_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'inquiry_messages: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        -- user_id 시도
        BEGIN
            DELETE FROM inquiry_messages WHERE user_id != admin_id;
            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            RAISE NOTICE 'inquiry_messages (user_id): % rows deleted', deleted_count;
        EXCEPTION WHEN undefined_column THEN
            RAISE NOTICE 'inquiry_messages: sender_id/user_id 컬럼 없음, 스킵';
        END;
    WHEN undefined_table THEN
        RAISE NOTICE 'inquiry_messages: 테이블 없음, 스킵';
    END;

    -- inquiries
    BEGIN
        DELETE FROM inquiries WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'inquiries: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'inquiries: user_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'inquiries: 테이블 없음, 스킵';
    END;

    -- messages
    BEGIN
        DELETE FROM messages WHERE sender_id != admin_id AND receiver_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'messages: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        -- from_user_id/to_user_id 시도
        BEGIN
            DELETE FROM messages WHERE from_user_id != admin_id AND to_user_id != admin_id;
            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            RAISE NOTICE 'messages (from/to_user_id): % rows deleted', deleted_count;
        EXCEPTION WHEN undefined_column THEN
            RAISE NOTICE 'messages: sender_id/receiver_id 컬럼 없음, 스킵';
        END;
    WHEN undefined_table THEN
        RAISE NOTICE 'messages: 테이블 없음, 스킵';
    END;

    -- account_deletions
    BEGIN
        DELETE FROM account_deletions WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'account_deletions: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'account_deletions: user_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'account_deletions: 테이블 없음, 스킵';
    END;

    -- recovery_requests
    BEGIN
        DELETE FROM recovery_requests WHERE user_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'recovery_requests: % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        RAISE NOTICE 'recovery_requests: user_id 컬럼 없음, 스킵';
    WHEN undefined_table THEN
        RAISE NOTICE 'recovery_requests: 테이블 없음, 스킵';
    END;

    -- organizations
    BEGIN
        DELETE FROM organizations WHERE owner_id != admin_id;
        GET DIAGNOSTICS deleted_count = ROW_COUNT;
        RAISE NOTICE 'organizations (owner_id): % rows deleted', deleted_count;
    EXCEPTION WHEN undefined_column THEN
        -- user_id 시도
        BEGIN
            DELETE FROM organizations WHERE user_id != admin_id;
            GET DIAGNOSTICS deleted_count = ROW_COUNT;
            RAISE NOTICE 'organizations (user_id): % rows deleted', deleted_count;
        EXCEPTION WHEN undefined_column THEN
            RAISE NOTICE 'organizations: owner_id/user_id 컬럼 없음, 스킵';
        END;
    WHEN undefined_table THEN
        RAISE NOTICE 'organizations: 테이블 없음, 스킵';
    END;

    -- ────────────────────────────────────────────────────────
    -- FINAL: profiles 삭제
    -- ────────────────────────────────────────────────────────

    DELETE FROM profiles WHERE id != admin_id;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE '=== profiles: % rows deleted ===', deleted_count;

    RAISE NOTICE '=== 테스트 사용자 삭제 완료 ===';
END $$;

-- ============================================================
-- STEP 4: auth.users 삭제 (별도 실행)
-- ============================================================

-- auth.users는 DO 블록 밖에서 직접 실행 필요
-- Supabase SQL Editor에서 service_role 권한으로 실행

DELETE FROM auth.users WHERE id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- 위 쿼리 실패 시:
-- 1. Supabase Dashboard → Authentication → Users
-- 2. 각 사용자 선택 → Delete 클릭 (봉쌤 계정 제외)

-- ============================================================
-- STEP 5: 삭제 후 검증
-- ============================================================

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
-- 실행 순서
-- ============================================================

/*
1. STEP 0 전체 실행 → 외래키 구조 확인
2. STEP 1 실행 → 문제 테이블 컬럼명 확인
3. STEP 2 실행 → 삭제될 행 수 미리보기
4. STEP 3 실행 → DO 블록으로 안전 삭제 (에러 시 스킵)
5. STEP 4 실행 → auth.users 삭제 (실패 시 Dashboard에서 수동)
6. STEP 5 실행 → 검증
*/
