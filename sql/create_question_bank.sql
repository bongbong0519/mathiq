-- ══════════════════════════════════════
--  create_question_bank
--  문제은행 DB 구현
--  1. questions 테이블
--  2. question_tags 테이블
--  3. RLS 정책
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- ─────────────────────────────────────
-- 1. questions 테이블
-- ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.questions (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  title        TEXT,
  content      TEXT        NOT NULL,           -- KaTeX 포함 문제 본문
  answer       TEXT,
  solution     TEXT,                           -- 풀이 과정
  school_level TEXT        CHECK (school_level IN ('초등','중등','고등')),
  grade        INTEGER     CHECK (grade BETWEEN 1 AND 6),
  semester     INTEGER     CHECK (semester IN (1, 2)),
  area         TEXT,                           -- 영역 (수와 연산, 문자와 식, ...)
  unit         TEXT,                           -- 단원
  sub_unit     TEXT,                           -- 소단원
  type         TEXT        NOT NULL DEFAULT '단답형'
                           CHECK (type IN ('객관식','단답형','서술형')),
  difficulty   INTEGER     NOT NULL DEFAULT 3
                           CHECK (difficulty BETWEEN 1 AND 5),
  status       TEXT        NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending','approved','rejected')),
  reject_reason TEXT,                          -- 거절 사유
  uploader_id  UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_by  UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at  TIMESTAMPTZ,
  created_at   TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS questions_status_idx       ON public.questions(status, created_at DESC);
CREATE INDEX IF NOT EXISTS questions_filter_idx       ON public.questions(school_level, grade, semester, area);
CREATE INDEX IF NOT EXISTS questions_uploader_idx     ON public.questions(uploader_id, created_at DESC);

ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────
-- 2. question_tags 테이블
-- ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.question_tags (
  id           UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  question_id  UUID        REFERENCES public.questions(id) ON DELETE CASCADE NOT NULL,
  tag          TEXT        NOT NULL,
  UNIQUE (question_id, tag)
);

ALTER TABLE public.question_tags ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────
-- 3. RLS 정책: questions
-- ─────────────────────────────────────

-- 승인된 문제: 로그인 유저 전체 조회
DROP POLICY IF EXISTS "questions_select_approved" ON public.questions;
CREATE POLICY "questions_select_approved"
  ON public.questions FOR SELECT
  TO authenticated
  USING (status = 'approved');

-- 본인 등록 문제: 상태 무관 조회
DROP POLICY IF EXISTS "questions_select_own" ON public.questions;
CREATE POLICY "questions_select_own"
  ON public.questions FOR SELECT
  TO authenticated
  USING (uploader_id = auth.uid());

-- 운영자: 전체 조회
DROP POLICY IF EXISTS "questions_select_admin" ON public.questions;
CREATE POLICY "questions_select_admin"
  ON public.questions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin','staff')
    )
  );

-- 등록: 선생님/원장/운영자
DROP POLICY IF EXISTS "questions_insert" ON public.questions;
CREATE POLICY "questions_insert"
  ON public.questions FOR INSERT
  TO authenticated
  WITH CHECK (
    uploader_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('teacher','director','admin','staff')
    )
  );

-- 수정: 본인 pending 문제 수정 가능
DROP POLICY IF EXISTS "questions_update_own" ON public.questions;
CREATE POLICY "questions_update_own"
  ON public.questions FOR UPDATE
  TO authenticated
  USING  (uploader_id = auth.uid() AND status = 'pending')
  WITH CHECK (uploader_id = auth.uid());

-- 운영자: 상태(승인/거절) 및 태깅 수정
DROP POLICY IF EXISTS "questions_update_admin" ON public.questions;
CREATE POLICY "questions_update_admin"
  ON public.questions FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin','staff')
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin','staff')
    )
  );

-- ─────────────────────────────────────
-- 4. RLS 정책: question_tags
-- ─────────────────────────────────────

-- 조회: 승인된 문제의 태그는 모두 볼 수 있음
DROP POLICY IF EXISTS "question_tags_select" ON public.question_tags;
CREATE POLICY "question_tags_select"
  ON public.question_tags FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.questions q
      WHERE q.id = question_id
        AND (q.status = 'approved' OR q.uploader_id = auth.uid()
             OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','staff')))
    )
  );

-- 태그 등록: 문제 등록자 또는 운영자
DROP POLICY IF EXISTS "question_tags_insert" ON public.question_tags;
CREATE POLICY "question_tags_insert"
  ON public.question_tags FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.questions q
      WHERE q.id = question_id
        AND (q.uploader_id = auth.uid()
             OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin','staff')))
    )
  );

-- 태그 삭제: 운영자만
DROP POLICY IF EXISTS "question_tags_delete" ON public.question_tags;
CREATE POLICY "question_tags_delete"
  ON public.question_tags FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('admin','staff')
    )
  );
