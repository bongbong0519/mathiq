-- ══════════════════════════════════════════════════════════════════════════════
-- 20260424_add_income_category.sql
-- accounting_income 테이블에 category 컬럼 추가
-- Supabase SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. category 컬럼 추가
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.accounting_income
  ADD COLUMN IF NOT EXISTS category VARCHAR(30) DEFAULT '정규수강료';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 기존 데이터 백필 (material_fee > 0 이면 '교재비')
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE public.accounting_income
SET category = '교재비'
WHERE material_fee > 0 AND (category IS NULL OR category = '정규수강료');

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. 컬럼 코멘트
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON COLUMN public.accounting_income.category IS '수입 카테고리: 정규수강료, 보충수업, 교재비, 특강, 기타';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  column_name,
  data_type,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'accounting_income'
  AND column_name = 'category';
-- 1행 나오면 성공

-- 백필 확인
SELECT category, COUNT(*) AS cnt
FROM public.accounting_income
GROUP BY category;
