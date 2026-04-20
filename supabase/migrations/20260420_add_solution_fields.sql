-- MathIQ: 해설 필드 추가 마이그레이션
-- 실행: Supabase Dashboard > SQL Editor에서 수동 실행

ALTER TABLE questions
  ADD COLUMN IF NOT EXISTS solution_latex text,
  ADD COLUMN IF NOT EXISTS solution_source text, -- 'original' | 'ai_generated' | 'ai_modified'
  ADD COLUMN IF NOT EXISTS ai_answer text,
  ADD COLUMN IF NOT EXISTS answer_confidence text, -- 'high' | 'medium' | 'low'
  ADD COLUMN IF NOT EXISTS solution_verified boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS solution_verified_by uuid REFERENCES profiles(id),
  ADD COLUMN IF NOT EXISTS solution_verified_at timestamptz;

-- 인덱스 (선택적: 검수 대기 필터용)
CREATE INDEX IF NOT EXISTS idx_questions_solution_verified
  ON questions(solution_verified)
  WHERE solution_verified = false;

COMMENT ON COLUMN questions.solution_latex IS '해설 LaTeX (원본 추출 또는 AI 생성)';
COMMENT ON COLUMN questions.solution_source IS '해설 출처: original(시험지 원본), ai_generated(AI 작성), ai_modified(AI 수정)';
COMMENT ON COLUMN questions.ai_answer IS 'AI가 추정한 정답 (사람이 검증 필요)';
COMMENT ON COLUMN questions.answer_confidence IS 'AI 정답 추정 신뢰도: high/medium/low';
