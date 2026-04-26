-- ============================================================
-- auth.users 유령 사용자 정리
-- 상황: profiles 1행, auth.users 9행 (8명 유령)
-- ============================================================

-- ■ 보존할 계정
-- UUID: c5a39205-83c8-4ac9-9a09-686e9e7aacc6

-- ============================================================
-- STEP 1: auth.users 참조 외래키 조회
-- ============================================================

SELECT
    tc.table_schema,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS references_table,
    ccu.column_name AS references_column,
    rc.delete_rule
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
  AND ccu.table_name = 'users';

-- ============================================================
-- STEP 2: 유령 사용자 ID 확인
-- ============================================================

-- 유령 = auth.users에 있지만 profiles에 없는 사용자
SELECT au.id, au.email, au.created_at
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
WHERE p.id IS NULL
  AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6';

-- ============================================================
-- STEP 3: 유령 사용자를 참조하는 데이터 찾기
-- ============================================================

-- 3-1. 유령 ID 목록 (아래 쿼리들에서 사용)
WITH orphans AS (
    SELECT au.id
    FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
)

-- 각 테이블에서 유령 참조 찾기 (auth.users.id 직접 참조 테이블)
-- ⚠️ STEP 1 결과에서 나온 테이블들을 아래에 추가

-- profiles (이미 정리됨 - 확인용)
SELECT 'profiles' AS tbl, COUNT(*) AS cnt
FROM profiles WHERE id IN (SELECT id FROM orphans);

-- 일반적으로 auth.users를 직접 참조하는 테이블들:
-- (Supabase 기본 구조 기반 추정)

-- identities (Supabase 내장)
SELECT 'auth.identities' AS tbl, COUNT(*) AS cnt
FROM auth.identities WHERE user_id IN (
    SELECT au.id FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
);

-- sessions (Supabase 내장)
SELECT 'auth.sessions' AS tbl, COUNT(*) AS cnt
FROM auth.sessions WHERE user_id IN (
    SELECT au.id FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
);

-- refresh_tokens (Supabase 내장)
SELECT 'auth.refresh_tokens' AS tbl, COUNT(*) AS cnt
FROM auth.refresh_tokens WHERE user_id IN (
    SELECT au.id FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
);

-- mfa_factors (Supabase 내장)
SELECT 'auth.mfa_factors' AS tbl, COUNT(*) AS cnt
FROM auth.mfa_factors WHERE user_id IN (
    SELECT au.id FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
);

-- ============================================================
-- STEP 4: auth 스키마 테이블 정리 (유령 데이터)
-- ============================================================

-- ⚠️ service_role 권한 필요!

BEGIN;

-- 4-1. auth.identities 정리
DELETE FROM auth.identities
WHERE user_id IN (
    SELECT au.id FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
);

-- 4-2. auth.sessions 정리
DELETE FROM auth.sessions
WHERE user_id IN (
    SELECT au.id FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
);

-- 4-3. auth.refresh_tokens 정리
DELETE FROM auth.refresh_tokens
WHERE user_id IN (
    SELECT au.id FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
);

-- 4-4. auth.mfa_factors 정리 (있다면)
DELETE FROM auth.mfa_factors
WHERE user_id IN (
    SELECT au.id FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
);

-- 4-5. auth.mfa_challenges 정리 (있다면)
DELETE FROM auth.mfa_challenges
WHERE factor_id IN (
    SELECT id FROM auth.mfa_factors WHERE user_id IN (
        SELECT au.id FROM auth.users au
        LEFT JOIN profiles p ON au.id = p.id
        WHERE p.id IS NULL
          AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
    )
);

COMMIT;

-- ============================================================
-- STEP 5: auth.users 삭제 (최종)
-- ============================================================

DELETE FROM auth.users
WHERE id IN (
    SELECT au.id FROM auth.users au
    LEFT JOIN profiles p ON au.id = p.id
    WHERE p.id IS NULL
      AND au.id != 'c5a39205-83c8-4ac9-9a09-686e9e7aacc6'
);

-- ============================================================
-- STEP 6: 검증
-- ============================================================

SELECT 'auth.users' AS tbl, COUNT(*) AS cnt,
       CASE WHEN COUNT(*) = 1 THEN '✅ 정상' ELSE '❌ 확인필요' END AS status
FROM auth.users;

SELECT id, email FROM auth.users;

-- ============================================================
-- 실행 순서
-- ============================================================
/*
1. STEP 1 실행 → 어떤 테이블이 auth.users 참조하는지 확인
2. STEP 2 실행 → 유령 ID 8개 확인
3. STEP 3 실행 → 유령 참조 데이터 찾기 (어느 테이블이 막는지)
4. STEP 4 실행 → auth 스키마 테이블 정리
5. STEP 5 실행 → auth.users 삭제
6. STEP 6 실행 → 1명만 남았는지 확인
*/
