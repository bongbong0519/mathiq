-- ══════════════════════════════════════
--  patch_messages
--  쪽지(메시지) 기능
--  1. messages 테이블 생성
--  2. RLS 정책 설정
--  Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════

-- ─────────────────────────────────────
-- 1. messages 테이블 생성
-- ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.messages (
  id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  sender_id   UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  receiver_id UUID        REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  title       TEXT        NOT NULL,
  body        TEXT        NOT NULL,
  is_read     BOOLEAN     NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS messages_receiver_idx ON public.messages(receiver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS messages_sender_idx   ON public.messages(sender_id,   created_at DESC);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- ─────────────────────────────────────
-- 2. RLS 정책
-- ─────────────────────────────────────

-- 받은 쪽지: receiver 본인만 조회
DROP POLICY IF EXISTS "messages_select_receiver" ON public.messages;
CREATE POLICY "messages_select_receiver"
  ON public.messages FOR SELECT
  TO authenticated
  USING (receiver_id = auth.uid());

-- 보낸 쪽지: sender 본인만 조회
DROP POLICY IF EXISTS "messages_select_sender" ON public.messages;
CREATE POLICY "messages_select_sender"
  ON public.messages FOR SELECT
  TO authenticated
  USING (sender_id = auth.uid());

-- 쪽지 발송: 로그인 유저가 본인 명의로만
DROP POLICY IF EXISTS "messages_insert_own" ON public.messages;
CREATE POLICY "messages_insert_own"
  ON public.messages FOR INSERT
  TO authenticated
  WITH CHECK (sender_id = auth.uid());

-- 읽음 처리: receiver 본인만 is_read 업데이트
DROP POLICY IF EXISTS "messages_update_read" ON public.messages;
CREATE POLICY "messages_update_read"
  ON public.messages FOR UPDATE
  TO authenticated
  USING (receiver_id = auth.uid())
  WITH CHECK (receiver_id = auth.uid());
