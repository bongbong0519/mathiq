-- ══════════════════════════════════════════════════════════════════
--  1:1 문의(inquiries) 확장 마이그레이션
--  - 카테고리 추가: bug, question, suggestion, etc
--  - 상태 확장: pending, in_progress, resolved, accepted, rejected
--
--  실행: Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════

-- 1. category 컬럼 기본값 설정 (이미 존재하면 타입 확인)
-- 기존 category 컬럼이 있지만 CHECK 제약조건이 없으므로 추가
DO $$
BEGIN
  -- category 컬럼이 없으면 추가
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
    AND table_name = 'inquiries'
    AND column_name = 'category'
  ) THEN
    ALTER TABLE public.inquiries ADD COLUMN category TEXT;
  END IF;
END $$;

-- 2. status 컬럼의 CHECK 제약조건 업데이트
-- 기존 제약조건 삭제 후 새로운 값들로 재생성
ALTER TABLE public.inquiries DROP CONSTRAINT IF EXISTS inquiries_status_check;
ALTER TABLE public.inquiries
  ADD CONSTRAINT inquiries_status_check
  CHECK (status IN ('pending', 'in_progress', 'resolved', 'accepted', 'rejected', 'open', 'closed'));

-- 3. 기존 'open' 상태를 'pending'으로 마이그레이션 (선택사항 - 일단 주석 처리)
-- UPDATE public.inquiries SET status = 'pending' WHERE status = 'open';

-- 4. category 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_inquiries_category ON public.inquiries(category);

-- 5. 기존 RLS 정책 확인 (이미 적용됨 - 본인 + staff만 접근)
-- inquiries_select, inquiries_insert, inquiries_update 정책 유지

-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- 테이블 구조 확인
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_name = 'inquiries';

-- CHECK 제약조건 확인
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint
-- WHERE conrelid = 'public.inquiries'::regclass;
