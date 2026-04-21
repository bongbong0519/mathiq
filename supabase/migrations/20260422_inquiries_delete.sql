-- ══════════════════════════════════════════════════════════════════
--  1:1 문의(inquiries) 삭제 RLS 정책
--
--  정책:
--  - 본인 문의: staff 답변(is_admin=true) 없을 때만 삭제 가능
--  - staff: 제한 없이 삭제 가능
--
--  실행: Supabase 대시보드 > SQL Editor에서 실행
-- ══════════════════════════════════════════════════════════════════

-- inquiries DELETE 정책
DROP POLICY IF EXISTS "inquiries_delete" ON public.inquiries;
CREATE POLICY "inquiries_delete"
  ON public.inquiries FOR DELETE
  TO authenticated
  USING (
    -- staff는 무조건 삭제 가능
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR
    -- 본인 문의 + staff 답변 없음
    (
      author_id = auth.uid()
      AND NOT EXISTS (
        SELECT 1 FROM public.inquiry_messages
        WHERE inquiry_id = id AND is_admin = true
      )
    )
  );

-- ══════════════════════════════════════════════════════════════════
--  검증 쿼리
-- ══════════════════════════════════════════════════════════════════

-- RLS 정책 확인
-- SELECT policyname, cmd, qual FROM pg_policies WHERE tablename = 'inquiries';

-- 테스트: staff 답변 있는 문의 확인
-- SELECT i.id, i.subject,
--   EXISTS(SELECT 1 FROM inquiry_messages m WHERE m.inquiry_id = i.id AND m.is_admin = true) as has_staff_reply
-- FROM inquiries i;
