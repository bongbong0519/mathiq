-- ══════════════════════════════════════════════════════════════════════════════
-- 05_views.sql
-- 회계 집계 뷰 5개
-- Supabase SQL Editor에서 실행 (01~04 테이블 생성 후)
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. v_monthly_income: 월별 수입 집계
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_monthly_income AS
SELECT
  teacher_id,
  month_year,
  COUNT(*) AS transaction_count,
  SUM(amount) AS total_income,
  SUM(base_amount) AS total_base,
  SUM(discount_amount) AS total_discount,
  SUM(material_fee) AS total_material,

  -- 결제수단별 집계
  SUM(CASE WHEN payment_method = 'cash' THEN amount ELSE 0 END) AS cash_income,
  SUM(CASE WHEN payment_method = 'transfer' THEN amount ELSE 0 END) AS transfer_income,
  SUM(CASE WHEN payment_method = 'card' THEN amount ELSE 0 END) AS card_income,
  SUM(CASE WHEN payment_method = 'pg' THEN amount ELSE 0 END) AS pg_income,
  SUM(CASE WHEN payment_method = 'other' THEN amount ELSE 0 END) AS other_income,

  -- 현금영수증 관련
  COUNT(CASE WHEN payment_method = 'cash' THEN 1 END) AS cash_count,
  COUNT(CASE WHEN payment_method = 'cash' AND cash_receipt_issued = TRUE THEN 1 END) AS cash_receipt_issued_count,
  SUM(CASE WHEN payment_method = 'cash' AND cash_receipt_issued = FALSE THEN amount ELSE 0 END) AS cash_receipt_pending_amount

FROM public.accounting_income
GROUP BY teacher_id, month_year;

COMMENT ON VIEW public.v_monthly_income IS '월별 수입 집계 (결제수단별, 현금영수증 현황 포함)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. v_monthly_expense: 월별 지출 집계
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_monthly_expense AS
SELECT
  teacher_id,
  month_year,
  COUNT(*) AS transaction_count,
  SUM(amount) AS total_expense,
  SUM(vat_amount) AS total_vat,

  -- 카테고리별 집계
  SUM(CASE WHEN category = 'rent' THEN amount ELSE 0 END) AS rent_expense,
  SUM(CASE WHEN category = 'utility' THEN amount ELSE 0 END) AS utility_expense,
  SUM(CASE WHEN category = 'material' THEN amount ELSE 0 END) AS material_expense,
  SUM(CASE WHEN category = 'equipment' THEN amount ELSE 0 END) AS equipment_expense,
  SUM(CASE WHEN category = 'communication' THEN amount ELSE 0 END) AS communication_expense,
  SUM(CASE WHEN category = 'advertising' THEN amount ELSE 0 END) AS advertising_expense,
  SUM(CASE WHEN category = 'staff_salary' THEN amount ELSE 0 END) AS staff_salary_expense,
  SUM(CASE WHEN category = 'other' THEN amount ELSE 0 END) AS other_expense,

  -- 고정비 vs 변동비
  SUM(CASE WHEN is_fixed = TRUE THEN amount ELSE 0 END) AS fixed_expense,
  SUM(CASE WHEN is_fixed = FALSE THEN amount ELSE 0 END) AS variable_expense

FROM public.accounting_expense
GROUP BY teacher_id, month_year;

COMMENT ON VIEW public.v_monthly_expense IS '월별 지출 집계 (카테고리별, 고정/변동 구분)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. v_monthly_pnl: 월별 손익 (Profit & Loss)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_monthly_pnl AS
SELECT
  COALESCE(i.teacher_id, e.teacher_id) AS teacher_id,
  COALESCE(i.month_year, e.month_year) AS month_year,
  COALESCE(i.total_income, 0) AS total_income,
  COALESCE(e.total_expense, 0) AS total_expense,
  COALESCE(i.total_income, 0) - COALESCE(e.total_expense, 0) AS net_profit,
  CASE
    WHEN COALESCE(i.total_income, 0) > 0
    THEN ROUND(
      (COALESCE(i.total_income, 0) - COALESCE(e.total_expense, 0))::NUMERIC
      / COALESCE(i.total_income, 0) * 100, 1
    )
    ELSE 0
  END AS profit_margin_pct,
  COALESCE(i.transaction_count, 0) AS income_count,
  COALESCE(e.transaction_count, 0) AS expense_count

FROM public.v_monthly_income i
FULL OUTER JOIN public.v_monthly_expense e
  ON i.teacher_id = e.teacher_id AND i.month_year = e.month_year;

COMMENT ON VIEW public.v_monthly_pnl IS '월별 손익 집계 (순이익, 이익률 %)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. v_yearly_summary: 연간 요약
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_yearly_summary AS
SELECT
  teacher_id,
  SUBSTRING(month_year FROM 1 FOR 4) AS year,
  SUM(total_income) AS yearly_income,
  SUM(total_expense) AS yearly_expense,
  SUM(net_profit) AS yearly_profit,
  CASE
    WHEN SUM(total_income) > 0
    THEN ROUND(SUM(net_profit)::NUMERIC / SUM(total_income) * 100, 1)
    ELSE 0
  END AS yearly_margin_pct,
  COUNT(*) AS active_months,
  ROUND(AVG(total_income)::NUMERIC, 0) AS avg_monthly_income,
  ROUND(AVG(total_expense)::NUMERIC, 0) AS avg_monthly_expense

FROM public.v_monthly_pnl
GROUP BY teacher_id, SUBSTRING(month_year FROM 1 FOR 4);

COMMENT ON VIEW public.v_yearly_summary IS '연간 요약 (연간 손익, 월평균)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. v_monthly_salary: 월별 강사 급여 요약 (학원용)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_monthly_salary AS
SELECT
  s.owner_id,
  s.month_year,
  COUNT(*) AS staff_count,
  SUM(s.gross_amount) AS total_gross,
  SUM(s.withholding_tax) AS total_withholding,
  SUM(s.four_insurance_amount) AS total_insurance,
  SUM(s.other_deduction) AS total_other_deduction,
  SUM(s.net_amount) AS total_net,
  COUNT(CASE WHEN s.payment_status = 'paid' THEN 1 END) AS paid_count,
  COUNT(CASE WHEN s.payment_status = 'pending' THEN 1 END) AS pending_count,
  SUM(CASE WHEN s.payment_status = 'pending' THEN s.net_amount ELSE 0 END) AS pending_amount

FROM public.accounting_staff_salary s
JOIN public.academy_staff st ON s.staff_id = st.id
WHERE st.is_active = TRUE
GROUP BY s.owner_id, s.month_year;

COMMENT ON VIEW public.v_monthly_salary IS '월별 강사 급여 요약 (학원용)';

-- ─────────────────────────────────────────────────────────────────────────────
-- 검증 쿼리
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
  table_name AS view_name,
  'VIEW' AS type
FROM information_schema.views
WHERE table_schema = 'public'
  AND table_name LIKE 'v_%'
  AND table_name IN ('v_monthly_income', 'v_monthly_expense', 'v_monthly_pnl', 'v_yearly_summary', 'v_monthly_salary')
ORDER BY table_name;
