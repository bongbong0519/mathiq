-- ══════════════════════════════════════════════════════════════════════════════
-- 20260424_simplify_expense_schema.sql
-- accounting_expense 테이블 스키마 단순화
-- Supabase SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. 기존 테이블 백업 (선택사항 - 데이터가 있는 경우)
-- ─────────────────────────────────────────────────────────────────────────────

-- 기존 데이터가 있다면 아래 실행하지 않고 ALTER로 진행
-- 기존 데이터 없으면 DROP 후 재생성이 더 깔끔

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. 기존 제약조건 제거
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.accounting_expense
  DROP CONSTRAINT IF EXISTS accounting_expense_category_check;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. 컬럼 추가/변경
-- ─────────────────────────────────────────────────────────────────────────────

-- payment_method 컬럼 추가
ALTER TABLE public.accounting_expense
  ADD COLUMN IF NOT EXISTS payment_method VARCHAR(20) DEFAULT 'transfer';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. 새 제약조건 (한글 카테고리)
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.accounting_expense
  ADD CONSTRAINT accounting_expense_category_korean
    CHECK (category IN ('임대료', '관리비', '교재구입', '사무용품', '식비', '교통비', '광고비', '통신비', '기타'));

ALTER TABLE public.accounting_expense
  ADD CONSTRAINT accounting_expense_payment_method_check
    CHECK (payment_method IN ('transfer', 'cash', 'card'));

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. 기존 영문 카테고리 → 한글 변환 (기존 데이터가 있을 경우)
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE public.accounting_expense SET category = '임대료' WHERE category = 'rent';
UPDATE public.accounting_expense SET category = '관리비' WHERE category = 'utility';
UPDATE public.accounting_expense SET category = '교재구입' WHERE category = 'material';
UPDATE public.accounting_expense SET category = '사무용품' WHERE category = 'equipment';
UPDATE public.accounting_expense SET category = '사무용품' WHERE category = 'supplies';
UPDATE public.accounting_expense SET category = '통신비' WHERE category = 'communication';
UPDATE public.accounting_expense SET category = '광고비' WHERE category = 'advertising';
UPDATE public.accounting_expense SET category = '기타' WHERE category = 'staff_salary';
UPDATE public.accounting_expense SET category = '기타' WHERE category = 'other';

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. 컬럼 코멘트 업데이트
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON COLUMN public.accounting_expense.category IS '지출 카테고리: 임대료, 관리비, 교재구입, 사무용품, 식비, 교통비, 광고비, 통신비, 기타';
COMMENT ON COLUMN public.accounting_expense.payment_method IS '결제수단: transfer(계좌이체), cash(현금), card(카드)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  column_name,
  data_type,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'accounting_expense'
ORDER BY ordinal_position;

-- 제약조건 확인
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.accounting_expense'::regclass;
