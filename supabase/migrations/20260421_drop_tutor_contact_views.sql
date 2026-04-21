-- ══════════════════════════════════════════════════════════════════
--  tutor_contact_views 테이블 제거
--
--  배경:
--  - Phase 1에서 "연락처 열람 500P" 방식 → "매칭 신청→수락" 방식으로 전환
--  - 기존 테이블 데이터는 20260421_tutor_matching_phase1.sql에서 삭제됨
--  - 이제 테이블 자체도 불필요
--
--  의존성:
--  - 이 테이블을 참조하는 FK 없음 (안전하게 DROP 가능)
--  - profiles, tutee_profiles를 참조하고 있었음 (CASCADE 불필요)
--
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════

-- RLS 정책 먼저 제거
DROP POLICY IF EXISTS "contact_views_select_own" ON public.tutor_contact_views;
DROP POLICY IF EXISTS "contact_views_insert_own" ON public.tutor_contact_views;

-- 테이블 제거
DROP TABLE IF EXISTS public.tutor_contact_views;

-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리:
--  SELECT tablename FROM pg_tables WHERE tablename = 'tutor_contact_views';
--  → 결과 없으면 삭제 완료
-- ══════════════════════════════════════════════════════════════════
