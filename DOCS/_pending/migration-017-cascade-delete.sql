-- ============================================================
-- Migration C-1: ON DELETE CASCADE 적용
-- 목적: 사용자 삭제 시 연관 데이터 자동 정리
-- ============================================================

-- ============================================================
-- PART 0: 현재 외래키 상태 조회
-- ============================================================

-- profiles 참조 외래키 현황
SELECT
    tc.table_name AS 테이블,
    kcu.column_name AS FK컬럼,
    rc.delete_rule AS 현재삭제규칙,
    CASE
        WHEN rc.delete_rule = 'CASCADE' THEN '✅ 이미 CASCADE'
        WHEN tc.table_name IN ('account_deletions', 'recovery_requests') THEN '⚠️ SET NULL 권장'
        ELSE '🔧 CASCADE 적용 필요'
    END AS 조치
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name = 'profiles'
    AND tc.table_schema = 'public'
ORDER BY
    CASE WHEN rc.delete_rule = 'CASCADE' THEN 1 ELSE 0 END,
    tc.table_name;

-- ============================================================
-- PART 1: CASCADE 적용 대상 테이블 (DO 블록으로 안전 적용)
-- ============================================================

-- ⚠️ 각 ALTER TABLE은 외래키 제약조건 이름이 필요
-- 아래는 일반적인 명명 규칙 기반 예시
-- 실제 제약조건 이름은 STEP 0 결과에서 확인 필요

-- 제약조건 이름 조회 (실행 필수)
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS ref_table,
    rc.delete_rule
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name IN ('profiles', 'users')
    AND tc.table_schema = 'public'
ORDER BY tc.table_name;

-- ============================================================
-- PART 2: CASCADE 일괄 적용 (제약조건 이름 확인 후 실행)
-- ============================================================

-- 패턴: DROP 후 ADD WITH CASCADE
-- 아래는 예시 - 실제 constraint_name으로 교체 필요!

/*
-- 예시: students 테이블
ALTER TABLE students
DROP CONSTRAINT students_teacher_id_fkey,
ADD CONSTRAINT students_teacher_id_fkey
    FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE CASCADE;

-- 예시: exams 테이블
ALTER TABLE exams
DROP CONSTRAINT exams_teacher_id_fkey,
ADD CONSTRAINT exams_teacher_id_fkey
    FOREIGN KEY (teacher_id) REFERENCES profiles(id) ON DELETE CASCADE;
*/

-- ============================================================
-- PART 3: 동적 CASCADE 적용 (자동화)
-- ============================================================

-- 제약조건 이름을 자동으로 찾아서 CASCADE 적용하는 함수
CREATE OR REPLACE FUNCTION apply_cascade_to_profile_refs()
RETURNS TABLE(table_name text, constraint_name text, status text) AS $$
DECLARE
    rec RECORD;
    sql_cmd TEXT;
BEGIN
    FOR rec IN
        SELECT
            tc.table_name,
            tc.constraint_name,
            kcu.column_name,
            ccu.column_name AS ref_column
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
            AND tc.table_schema = 'public'
            AND rc.delete_rule != 'CASCADE'
            -- SET NULL 대상 제외
            AND tc.table_name NOT IN ('account_deletions', 'recovery_requests')
    LOOP
        BEGIN
            -- DROP 기존 제약조건
            sql_cmd := format(
                'ALTER TABLE %I DROP CONSTRAINT %I',
                rec.table_name, rec.constraint_name
            );
            EXECUTE sql_cmd;

            -- ADD CASCADE 제약조건
            sql_cmd := format(
                'ALTER TABLE %I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES profiles(id) ON DELETE CASCADE',
                rec.table_name, rec.constraint_name, rec.column_name
            );
            EXECUTE sql_cmd;

            table_name := rec.table_name;
            constraint_name := rec.constraint_name;
            status := '✅ CASCADE 적용됨';
            RETURN NEXT;
        EXCEPTION WHEN OTHERS THEN
            table_name := rec.table_name;
            constraint_name := rec.constraint_name;
            status := '❌ 오류: ' || SQLERRM;
            RETURN NEXT;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 함수 실행
SELECT * FROM apply_cascade_to_profile_refs();

-- 함수 정리 (선택)
-- DROP FUNCTION apply_cascade_to_profile_refs();

-- ============================================================
-- PART 4: SET NULL 적용 (이력 보존 테이블)
-- ============================================================

-- account_deletions: 삭제 이력 보존
DO $$
DECLARE
    const_name TEXT;
BEGIN
    SELECT tc.constraint_name INTO const_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
    WHERE tc.table_name = 'account_deletions'
        AND ccu.table_name = 'profiles'
        AND tc.constraint_type = 'FOREIGN KEY';

    IF const_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE account_deletions DROP CONSTRAINT %I', const_name);
        EXECUTE format('ALTER TABLE account_deletions ADD CONSTRAINT %I FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE SET NULL', const_name);
        RAISE NOTICE 'account_deletions: SET NULL 적용됨';
    END IF;
END $$;

-- recovery_requests: 복구 요청 이력 보존
DO $$
DECLARE
    const_name TEXT;
BEGIN
    SELECT tc.constraint_name INTO const_name
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
    JOIN information_schema.constraint_column_usage ccu
        ON ccu.constraint_name = tc.constraint_name
    WHERE tc.table_name = 'recovery_requests'
        AND ccu.table_name = 'profiles'
        AND tc.constraint_type = 'FOREIGN KEY';

    IF const_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE recovery_requests DROP CONSTRAINT %I', const_name);
        EXECUTE format('ALTER TABLE recovery_requests ADD CONSTRAINT %I FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE SET NULL', const_name);
        RAISE NOTICE 'recovery_requests: SET NULL 적용됨';
    END IF;
END $$;

-- ============================================================
-- PART 5: delete_user_permanently RPC 함수
-- ============================================================

CREATE OR REPLACE FUNCTION delete_user_permanently(target_user_id UUID)
RETURNS JSON AS $$
DECLARE
    result JSON;
    deleted_tables TEXT[] := '{}';
    admin_id UUID := 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';
BEGIN
    -- 관리자 삭제 방지
    IF target_user_id = admin_id THEN
        RETURN json_build_object('success', false, 'error', '관리자 계정은 삭제할 수 없습니다');
    END IF;

    -- CASCADE가 적용되어 있으면 profiles 삭제만으로 연쇄 삭제됨
    -- 하지만 안전을 위해 명시적 삭제도 수행

    -- 시험 관련
    DELETE FROM exam_results WHERE teacher_id = target_user_id;
    DELETE FROM exam_sessions WHERE teacher_id = target_user_id;
    DELETE FROM exam_questions WHERE teacher_id = target_user_id;
    DELETE FROM exam_assignments WHERE teacher_id = target_user_id;
    DELETE FROM exams WHERE teacher_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'exams');

    -- 회계 관련
    DELETE FROM accounting_staff_salary WHERE teacher_id = target_user_id;
    DELETE FROM accounting_income WHERE teacher_id = target_user_id;
    DELETE FROM accounting_expense WHERE teacher_id = target_user_id;
    DELETE FROM billing_invoices WHERE teacher_id = target_user_id;
    DELETE FROM payment_reminders WHERE teacher_id = target_user_id;
    DELETE FROM teacher_payment_settings WHERE teacher_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'accounting');

    -- 학생/자료 관련
    DELETE FROM teacher_comments WHERE teacher_id = target_user_id;
    DELETE FROM students WHERE teacher_id = target_user_id;
    DELETE FROM material_shares WHERE teacher_id = target_user_id;
    DELETE FROM class_materials WHERE teacher_id = target_user_id;
    DELETE FROM materials WHERE teacher_id = target_user_id;
    DELETE FROM questions WHERE teacher_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'students_materials');

    -- 캘린더/SMS
    DELETE FROM calendar_events WHERE teacher_id = target_user_id;
    DELETE FROM sms_history WHERE teacher_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'calendar_sms');

    -- 학원 직원
    DELETE FROM academy_staff WHERE teacher_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'academy_staff');

    -- 과외 매칭
    DELETE FROM tutor_match_requests WHERE user_id = target_user_id;
    DELETE FROM tutor_matches WHERE tutor_id = target_user_id;
    DELETE FROM tutor_profiles WHERE user_id = target_user_id;
    DELETE FROM tutee_profiles WHERE user_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'tutor');

    -- 게시판
    DELETE FROM post_comments WHERE author_id = target_user_id;
    DELETE FROM posts WHERE author_id = target_user_id;
    DELETE FROM notice_reads WHERE user_id = target_user_id;
    DELETE FROM notices WHERE author_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'posts');

    -- 피드백/문의
    DELETE FROM feedback_votes WHERE user_id = target_user_id;
    DELETE FROM feedback_comments WHERE author_id = target_user_id;
    DELETE FROM feedback_posts WHERE author_id = target_user_id;
    DELETE FROM inquiry_messages WHERE sender_id = target_user_id;
    DELETE FROM inquiries WHERE user_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'feedback_inquiry');

    -- 기타
    DELETE FROM messages WHERE sender_id = target_user_id OR receiver_id = target_user_id;
    DELETE FROM privacy_consents WHERE user_id = target_user_id;
    DELETE FROM uploaded_files WHERE user_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'misc');

    -- 기관 (소유자인 경우)
    DELETE FROM organizations WHERE owner_id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'organizations');

    -- account_deletions, recovery_requests는 SET NULL이므로 자동 처리됨

    -- profiles 삭제
    DELETE FROM profiles WHERE id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'profiles');

    -- auth.users 삭제 (auth 스키마 테이블 먼저 정리)
    DELETE FROM auth.identities WHERE user_id = target_user_id;
    DELETE FROM auth.sessions WHERE user_id = target_user_id;
    DELETE FROM auth.refresh_tokens WHERE user_id = target_user_id;
    DELETE FROM auth.mfa_factors WHERE user_id = target_user_id;
    DELETE FROM auth.users WHERE id = target_user_id;
    deleted_tables := array_append(deleted_tables, 'auth.users');

    RETURN json_build_object(
        'success', true,
        'deleted_user_id', target_user_id,
        'cleaned_tables', deleted_tables
    );
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM,
        'user_id', target_user_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC 호출 예시
-- SELECT delete_user_permanently('target-uuid-here');

-- ============================================================
-- PART 6: 30일 자동 삭제 (pg_cron 스케줄)
-- ============================================================

-- 30일 지난 삭제 대기 계정 자동 정리
CREATE OR REPLACE FUNCTION auto_delete_expired_accounts()
RETURNS JSON AS $$
DECLARE
    expired_user RECORD;
    results JSON[] := '{}';
    delete_result JSON;
BEGIN
    FOR expired_user IN
        SELECT user_id, deleted_at
        FROM account_deletions
        WHERE status = 'pending'
          AND deleted_at < NOW() - INTERVAL '30 days'
          AND user_id IS NOT NULL
    LOOP
        delete_result := delete_user_permanently(expired_user.user_id);
        results := array_append(results, delete_result);

        -- 삭제 완료 상태 업데이트
        UPDATE account_deletions
        SET status = 'completed', completed_at = NOW()
        WHERE user_id = expired_user.user_id;
    END LOOP;

    RETURN json_build_object(
        'processed_count', array_length(results, 1),
        'results', results
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- pg_cron 스케줄 설정 (Supabase Dashboard → Database → Extensions → pg_cron 활성화 필요)
-- 매일 자정(UTC) 실행
-- SELECT cron.schedule('auto-delete-expired', '0 0 * * *', 'SELECT auto_delete_expired_accounts()');

-- ============================================================
-- PART 7: 적용 후 검증
-- ============================================================

-- CASCADE 적용 상태 확인
SELECT
    tc.table_name,
    kcu.column_name,
    rc.delete_rule,
    CASE
        WHEN rc.delete_rule = 'CASCADE' THEN '✅'
        WHEN rc.delete_rule = 'SET NULL' THEN '⚠️'
        ELSE '❌'
    END AS status
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND ccu.table_name = 'profiles'
    AND tc.table_schema = 'public'
ORDER BY tc.table_name;

-- ============================================================
-- 실행 순서
-- ============================================================
/*
1. PART 0 실행 → 현재 외래키 상태 확인
2. PART 1 실행 → 제약조건 이름 확인
3. PART 3 실행 → CASCADE 자동 적용 (함수 생성 + 실행)
4. PART 4 실행 → SET NULL 적용 (이력 보존 테이블)
5. PART 5 실행 → delete_user_permanently 함수 생성
6. PART 6 실행 → auto_delete_expired_accounts 함수 생성
7. PART 7 실행 → 적용 검증

pg_cron 스케줄 설정:
- Supabase Dashboard → Database → Extensions → pg_cron 활성화
- SQL Editor에서 cron.schedule 실행
*/
