-- ══════════════════════════════════════════════════════════════════
--  분류 체계 DB 구축 - 지수와 로그 (5단원 13소단원 43유형)
--
--  ⚠️ 주의: 섹션 1에서 기존 questions 데이터 전체 삭제함!
--  실행 전 백업 여부 확인 필요
--
--  실행 순서: 섹션 1 → 2 → 3 → 4 → 5 → 6 순서대로
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 1: 기존 questions 데이터 삭제                              │
-- │  ⚠️ 경고: 모든 문제 데이터가 삭제됩니다!                         │
-- └─────────────────────────────────────────────────────────────────┘

-- 기존 테스트 데이터 전체 삭제 (봉쌤 확정)
DELETE FROM public.questions;


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 2: 카테고리 테이블 생성                                    │
-- └─────────────────────────────────────────────────────────────────┘

-- 단원 테이블
CREATE TABLE IF NOT EXISTS public.units (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  school_level  TEXT        NOT NULL,      -- '고등'
  grade         INTEGER     NOT NULL,       -- 2
  semester      INTEGER     NOT NULL,       -- 1
  area          TEXT        NOT NULL,       -- '지수와 로그'
  name          TEXT        NOT NULL,       -- '지수'
  display_order INTEGER,
  description   TEXT,
  is_extra_unit BOOLEAN     DEFAULT false,  -- 통합형 단원 표시
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_units_area ON public.units(school_level, grade, semester, area);
CREATE INDEX IF NOT EXISTS idx_units_order ON public.units(area, display_order);

-- 소단원 테이블
CREATE TABLE IF NOT EXISTS public.sub_units (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id       UUID        REFERENCES public.units(id) ON DELETE CASCADE NOT NULL,
  name          TEXT        NOT NULL,
  display_order INTEGER,
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sub_units_unit ON public.sub_units(unit_id);
CREATE INDEX IF NOT EXISTS idx_sub_units_order ON public.sub_units(unit_id, display_order);

-- 유형 테이블
CREATE TABLE IF NOT EXISTS public.question_types (
  id                 UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  sub_unit_id        UUID        REFERENCES public.sub_units(id) ON DELETE CASCADE NOT NULL,
  name               TEXT        NOT NULL,
  difficulty_default TEXT        CHECK (difficulty_default IN ('하','중','상')),
  description        TEXT,
  display_order      INTEGER,
  created_at         TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_question_types_sub_unit ON public.question_types(sub_unit_id);
CREATE INDEX IF NOT EXISTS idx_question_types_order ON public.question_types(sub_unit_id, display_order);


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 3: RLS 정책                                                │
-- └─────────────────────────────────────────────────────────────────┘

ALTER TABLE public.units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sub_units ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.question_types ENABLE ROW LEVEL SECURITY;

-- units: 모든 인증 사용자 조회 가능
DROP POLICY IF EXISTS "units_select_all" ON public.units;
CREATE POLICY "units_select_all"
  ON public.units FOR SELECT
  TO authenticated
  USING (true);

-- units: staff만 수정 가능
DROP POLICY IF EXISTS "units_staff_all" ON public.units;
CREATE POLICY "units_staff_all"
  ON public.units FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff'));

-- sub_units: 모든 인증 사용자 조회 가능
DROP POLICY IF EXISTS "sub_units_select_all" ON public.sub_units;
CREATE POLICY "sub_units_select_all"
  ON public.sub_units FOR SELECT
  TO authenticated
  USING (true);

-- sub_units: staff만 수정 가능
DROP POLICY IF EXISTS "sub_units_staff_all" ON public.sub_units;
CREATE POLICY "sub_units_staff_all"
  ON public.sub_units FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff'));

-- question_types: 모든 인증 사용자 조회 가능
DROP POLICY IF EXISTS "question_types_select_all" ON public.question_types;
CREATE POLICY "question_types_select_all"
  ON public.question_types FOR SELECT
  TO authenticated
  USING (true);

-- question_types: staff만 수정 가능
DROP POLICY IF EXISTS "question_types_staff_all" ON public.question_types;
CREATE POLICY "question_types_staff_all"
  ON public.question_types FOR ALL
  TO authenticated
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff'))
  WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'staff'));


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 4: questions 테이블에 FK 컬럼 추가                         │
-- └─────────────────────────────────────────────────────────────────┘

ALTER TABLE public.questions
  ADD COLUMN IF NOT EXISTS unit_id UUID REFERENCES public.units(id),
  ADD COLUMN IF NOT EXISTS sub_unit_id UUID REFERENCES public.sub_units(id),
  ADD COLUMN IF NOT EXISTS question_type_id UUID REFERENCES public.question_types(id),
  ADD COLUMN IF NOT EXISTS difficulty TEXT CHECK (difficulty IN ('하','중','상'));

CREATE INDEX IF NOT EXISTS idx_questions_unit ON public.questions(unit_id);
CREATE INDEX IF NOT EXISTS idx_questions_sub_unit ON public.questions(sub_unit_id);
CREATE INDEX IF NOT EXISTS idx_questions_type ON public.questions(question_type_id);


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 5: 초기 데이터 - 지수와 로그 (5단원 13소단원 43유형)        │
-- └─────────────────────────────────────────────────────────────────┘

-- ════════════════════════════════════════════════════════════
-- 단원 1: 지수
-- ════════════════════════════════════════════════════════════
INSERT INTO public.units (id, school_level, grade, semester, area, name, display_order, is_extra_unit)
VALUES ('11111111-1111-1111-1111-000000000001', '고등', 2, 1, '지수와 로그', '지수', 1, false);

-- 소단원 1-1: 거듭제곱근의 뜻과 성질
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000001', '11111111-1111-1111-1111-000000000001', '거듭제곱근의 뜻과 성질', 1);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000001', '거듭제곱근의 값 구하기', '하', 1),
('22222222-2222-2222-2222-000000000001', '거듭제곱근의 성질 활용', '중', 2),
('22222222-2222-2222-2222-000000000001', '거듭제곱근의 대소 비교', '중', 3),
('22222222-2222-2222-2222-000000000001', '거듭제곱근 식의 계산', '중', 4);

-- 소단원 1-2: 지수의 확장
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000002', '11111111-1111-1111-1111-000000000001', '지수의 확장', 2);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000002', '유리수 지수의 계산', '하', 1),
('22222222-2222-2222-2222-000000000002', '지수법칙 활용', '중', 2),
('22222222-2222-2222-2222-000000000002', '지수식의 값 구하기', '중', 3),
('22222222-2222-2222-2222-000000000002', '지수식의 조건부 문제', '상', 4);


-- ════════════════════════════════════════════════════════════
-- 단원 2: 로그
-- ════════════════════════════════════════════════════════════
INSERT INTO public.units (id, school_level, grade, semester, area, name, display_order, is_extra_unit)
VALUES ('11111111-1111-1111-1111-000000000002', '고등', 2, 1, '지수와 로그', '로그', 2, false);

-- 소단원 2-1: 로그의 뜻과 성질
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000003', '11111111-1111-1111-1111-000000000002', '로그의 뜻과 성질', 1);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000003', '로그의 정의 활용', '하', 1),
('22222222-2222-2222-2222-000000000003', '로그의 성질 계산', '중', 2),
('22222222-2222-2222-2222-000000000003', '로그의 밑 변환', '중', 3),
('22222222-2222-2222-2222-000000000003', '로그식의 값 구하기', '중', 4),
('22222222-2222-2222-2222-000000000003', '로그의 조건부 문제', '상', 5);

-- 소단원 2-2: 상용로그
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000004', '11111111-1111-1111-1111-000000000002', '상용로그', 2);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000004', '상용로그의 지표와 가수', '하', 1),
('22222222-2222-2222-2222-000000000004', '상용로그표 활용', '중', 2),
('22222222-2222-2222-2222-000000000004', '자릿수 문제', '중', 3),
('22222222-2222-2222-2222-000000000004', '소수점 자리 문제', '상', 4);


-- ════════════════════════════════════════════════════════════
-- 단원 3: 지수함수
-- ════════════════════════════════════════════════════════════
INSERT INTO public.units (id, school_level, grade, semester, area, name, display_order, is_extra_unit)
VALUES ('11111111-1111-1111-1111-000000000003', '고등', 2, 1, '지수와 로그', '지수함수', 3, false);

-- 소단원 3-1: 지수함수의 그래프
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000005', '11111111-1111-1111-1111-000000000003', '지수함수의 그래프', 1);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000005', '지수함수의 그래프 개형', '하', 1),
('22222222-2222-2222-2222-000000000005', '지수함수의 평행이동·대칭이동', '중', 2),
('22222222-2222-2222-2222-000000000005', '지수함수의 점근선', '중', 3),
('22222222-2222-2222-2222-000000000005', '지수함수의 최대·최소', '상', 4),
('22222222-2222-2222-2222-000000000005', '지수함수의 그래프와 직선', '상', 5);

-- 소단원 3-2: 지수방정식과 지수부등식
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000006', '11111111-1111-1111-1111-000000000003', '지수방정식과 지수부등식', 2);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000006', '기본 지수방정식', '하', 1),
('22222222-2222-2222-2222-000000000006', '치환을 이용한 지수방정식', '중', 2),
('22222222-2222-2222-2222-000000000006', '기본 지수부등식', '중', 3),
('22222222-2222-2222-2222-000000000006', '치환을 이용한 지수부등식', '상', 4);


-- ════════════════════════════════════════════════════════════
-- 단원 4: 로그함수
-- ════════════════════════════════════════════════════════════
INSERT INTO public.units (id, school_level, grade, semester, area, name, display_order, is_extra_unit)
VALUES ('11111111-1111-1111-1111-000000000004', '고등', 2, 1, '지수와 로그', '로그함수', 4, false);

-- 소단원 4-1: 로그함수의 그래프
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000007', '11111111-1111-1111-1111-000000000004', '로그함수의 그래프', 1);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000007', '로그함수의 그래프 개형', '하', 1),
('22222222-2222-2222-2222-000000000007', '로그함수의 평행이동·대칭이동', '중', 2),
('22222222-2222-2222-2222-000000000007', '로그함수의 정의역', '중', 3),
('22222222-2222-2222-2222-000000000007', '로그함수의 최대·최소', '상', 4),
('22222222-2222-2222-2222-000000000007', '로그함수의 그래프와 직선', '상', 5);

-- 소단원 4-2: 로그방정식과 로그부등식
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000008', '11111111-1111-1111-1111-000000000004', '로그방정식과 로그부등식', 2);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000008', '기본 로그방정식', '하', 1),
('22222222-2222-2222-2222-000000000008', '치환을 이용한 로그방정식', '중', 2),
('22222222-2222-2222-2222-000000000008', '기본 로그부등식', '중', 3),
('22222222-2222-2222-2222-000000000008', '치환을 이용한 로그부등식', '상', 4),
('22222222-2222-2222-2222-000000000008', '진수 조건 활용', '상', 5);


-- ════════════════════════════════════════════════════════════
-- 단원 5: 지수·로그 통합형 (수능 킬러)
-- ════════════════════════════════════════════════════════════
INSERT INTO public.units (id, school_level, grade, semester, area, name, display_order, is_extra_unit)
VALUES ('11111111-1111-1111-1111-000000000005', '고등', 2, 1, '지수와 로그', '지수·로그 통합형', 5, true);

-- 소단원 5-1: 지수·로그 그래프 통합
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000009', '11111111-1111-1111-1111-000000000005', '지수·로그 그래프 통합', 1);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000009', '지수함수와 로그함수의 관계', '중', 1),
('22222222-2222-2222-2222-000000000009', '역함수 관계 활용', '상', 2),
('22222222-2222-2222-2222-000000000009', '그래프의 교점 문제', '상', 3);

-- 소단원 5-2: 지수·로그 방정식·부등식 통합
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000010', '11111111-1111-1111-1111-000000000005', '지수·로그 방정식·부등식 통합', 2);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000010', '지수와 로그 혼합 방정식', '상', 1),
('22222222-2222-2222-2222-000000000010', '지수와 로그 혼합 부등식', '상', 2),
('22222222-2222-2222-2222-000000000010', '연립방정식·부등식', '상', 3);

-- 소단원 5-3: 새로운 정의를 이용한 문제
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000011', '11111111-1111-1111-1111-000000000005', '새로운 정의를 이용한 문제', 3);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000011', '새로운 연산 정의', '상', 1),
('22222222-2222-2222-2222-000000000011', '조건을 만족하는 값 찾기', '상', 2);

-- 소단원 5-4: 킬러형
INSERT INTO public.sub_units (id, unit_id, name, display_order)
VALUES ('22222222-2222-2222-2222-000000000012', '11111111-1111-1111-1111-000000000005', '킬러형', 4);

INSERT INTO public.question_types (sub_unit_id, name, difficulty_default, display_order) VALUES
('22222222-2222-2222-2222-000000000012', '수능 21번형 (지수·로그)', '상', 1),
('22222222-2222-2222-2222-000000000012', '수능 30번형 (지수·로그)', '상', 2);


-- ┌─────────────────────────────────────────────────────────────────┐
-- │  섹션 6: 검증 쿼리                                               │
-- └─────────────────────────────────────────────────────────────────┘

-- 아래 쿼리로 결과 확인:

-- 1. 단원 개수 확인 (5개여야 함)
-- SELECT COUNT(*) FROM units WHERE area = '지수와 로그';

-- 2. 소단원 개수 확인 (12개여야 함 - 5-4 킬러형 포함하면 12개)
-- SELECT COUNT(*) FROM sub_units;

-- 3. 유형 개수 확인 (43개여야 함)
-- SELECT COUNT(*) FROM question_types;

-- 4. 전체 체계 조회
-- SELECT
--   u.name as 단원,
--   su.name as 소단원,
--   qt.name as 유형,
--   qt.difficulty_default as 난이도
-- FROM units u
-- JOIN sub_units su ON su.unit_id = u.id
-- JOIN question_types qt ON qt.sub_unit_id = su.id
-- WHERE u.area = '지수와 로그'
-- ORDER BY u.display_order, su.display_order, qt.display_order;

-- ══════════════════════════════════════════════════════════════════
